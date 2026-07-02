# frozen_string_literal: true

require "prism"
require_relative "definition"

module CallMap
  # The single boundary that touches Prism.
  #
  # Prism node types (ClassNode / ModuleNode / DefNode ...) are referenced only
  # here. Everything else in the codebase works with Definition, so the parser
  # can be swapped out later by replacing just this class.
  class DefinitionCollector < Prism::Visitor
    # Parse `source` and return the list of definitions found in it.
    #
    # @param source [String] Ruby source code
    # @param path [String] file path the source came from (kept on each Definition)
    # @return [Array<Definition>]
    def self.collect(source, path:)
      new(path).collect(source)
    end

    def initialize(path)
      super()                # Prism::Visitor#initialize takes no args
      @path = path
      @namespace = []        # stack of enclosing class/module names
      @singletons = []       # per-scope singleton owner (nil / String / :unresolved)
      @definitions = []
    end

    def collect(source)
      # Prism.parse returns a ParseResult; .value is the root (ProgramNode).
      # accept(self) starts the visitor traversal from the root.
      Prism.parse(source).value.accept(self)
      @definitions
    end

    # Called when the traversal reaches a `class` definition.
    def visit_class_node(node)
      enter_namespace(node.constant_path) do
        @definitions << build_definition(:class, current_namespace, node, superclass: constant_name(node.superclass))
        super # descend into the class body (its methods etc.)
      end
    end

    # Called when the traversal reaches a `module` definition.
    def visit_module_node(node)
      enter_namespace(node.constant_path) do
        @definitions << build_definition(:module, current_namespace, node)
        super
      end
    end

    # Called for `class << self`, `class << SomeConstant`, and `class << obj`.
    def visit_singleton_class_node(node)
      within_singleton(singleton_owner(node.expression)) do
        super
      end
    end

    # Called for every `def` — `def foo`, `def self.foo`, and `def Foo.bar`.
    def visit_def_node(node)
      info = method_kind_and_owner(node.receiver)
      # info is nil when the method belongs to an unresolvable receiver
      # (e.g. `class << obj`); such defs are skipped rather than mis-registered.
      @definitions << build_definition(info[:kind], node.name.to_s, node, owner: info[:owner]) if info
      # No super — do not recurse into method bodies. Nested defs inside a
      # method are runtime-only and should not appear in the static index.
    end

    private

    # Decide the (kind, owner) of a method from its `def` receiver.
    # Returns nil to signal "do not register this def".
    #
    # - no receiver (`def foo`): depends on the enclosing scope
    #     - inside `class << self` / `class << Const`  -> class method on that owner
    #     - inside `class << obj` (unresolvable)        -> nil (skip)
    #     - otherwise                                    -> instance method on the current namespace
    # - self receiver     (`def self.foo`) -> class method on the current namespace
    # - constant receiver (`def Foo.bar`)  -> class method owned by that constant
    def method_kind_and_owner(receiver)
      case receiver
      when nil
        singleton_scope_kind_and_owner
      when Prism::SelfNode
        { kind: :class_method, owner: current_namespace }
      when Prism::ConstantReadNode, Prism::ConstantPathNode
        { kind: :class_method, owner: qualified_constant(receiver) }
      end
    end

    # Interpret the innermost singleton scope for a bodyless `def`.
    def singleton_scope_kind_and_owner
      owner = current_singleton_owner
      case owner
      when nil then { kind: :instance_method, owner: current_namespace }
      when :unresolved then nil
      else { kind: :class_method, owner: owner }
      end
    end

    def build_definition(kind, name, node, owner: nil, superclass: nil)
      nesting = %i[instance_method class_method].include?(kind) ? lexical_nesting : nil
      Definition.new(kind: kind, name: name, owner: owner, path: @path, line: node.location.start_line,
                     lexical_nesting: nesting, superclass: superclass)
    end

    # The lexical scope stack at the definition site, outermost first
    # (e.g. ["Reports", "Runner"]). Ruby resolves relative constants against
    # each scope from innermost outward, so the whole stack is preserved.
    # A compact-style entry stays as one element ("Admin::Runner"), so its
    # intermediate segments are never used as lookup prefixes.
    def lexical_nesting
      return nil if @namespace.empty?

      @namespace.dup
    end

    # Route to absolute or relative namespace handling based on the constant node.
    def enter_namespace(constant_node, &)
      name = constant_name(constant_node)
      ns = current_namespace

      if absolute_constant?(constant_node) || already_qualified?(name, ns)
        within_absolute_namespace(name, &)
      else
        within_namespace(name, &)
      end
    end

    # A constant path like `Admin::ReportsController` inside `module Admin`
    # already contains the enclosing namespace — pushing it would produce
    # `Admin::Admin::ReportsController`.
    def already_qualified?(name, namespace)
      return false if namespace.empty? || name.nil?

      name == namespace || name.start_with?("#{namespace}::")
    end

    # Push `name` while the block runs, then always pop it back off.
    # Entering a named class/module also pushes a nil singleton owner, so a
    # normal class nested inside `class << self` is not mistaken for a singleton.
    def within_namespace(name)
      @namespace.push(name)
      @singletons.push(nil)
      yield
    ensure
      @namespace.pop
      @singletons.pop
    end

    # For absolute constant paths (`class ::Foo::Bar`), temporarily replace
    # the namespace stack with just the constant's own segments.
    def within_absolute_namespace(name)
      saved_namespace = @namespace
      saved_singletons = @singletons
      @namespace = [name]
      @singletons = [nil]
      yield
    ensure
      @namespace = saved_namespace
      @singletons = saved_singletons
    end

    # Track the class-method owner implied by the current singleton scope.
    # owner is a String ("class << Foo"), or :unresolved ("class << obj").
    def within_singleton(owner)
      @singletons.push(owner)
      yield
    ensure
      @singletons.pop
    end

    def current_singleton_owner
      @singletons.last
    end

    # Resolve the owner for a `class << expression` header.
    # - self             -> the enclosing class/module
    # - a constant        -> that (namespace-qualified) constant
    # - anything else     -> :unresolved (a runtime object we can't name statically)
    def singleton_owner(expression)
      case expression
      when Prism::SelfNode then current_namespace
      when Prism::ConstantReadNode, Prism::ConstantPathNode then qualified_constant(expression)
      else :unresolved
      end
    end

    # Best-effort qualification of a constant receiver with the current
    # namespace. Full Ruby constant resolution is out of scope for the MVP;
    # a relative constant is simply prefixed with the enclosing namespace.
    def qualified_constant(node)
      name = constant_name(node)
      ns = current_namespace
      return name if name.nil? || ns.empty? || absolute_constant?(node)
      return ns if name == ns || ns.end_with?("::#{name}")

      "#{ns}::#{name}"
    end

    # A ConstantPathNode whose root parent is nil represents an absolute
    # constant path (e.g. `::Reports::Generator`). Such constants should
    # not be prefixed with the enclosing namespace.
    def absolute_constant?(node)
      return false unless node.is_a?(Prism::ConstantPathNode)

      root = node
      root = root.parent while root.parent.is_a?(Prism::ConstantPathNode)
      root.parent.nil?
    end

    def current_namespace
      @namespace.join("::")
    end

    # Build a qualified name string from a constant node.
    # - ConstantReadNode  (`Foo`)        -> "Foo"
    # - ConstantPathNode  (`Admin::Foo`) -> "Admin::Foo"
    def constant_name(node)
      case node
      when Prism::ConstantReadNode
        node.name.to_s
      when Prism::ConstantPathNode
        [constant_name(node.parent), node.name.to_s].compact.join("::")
      end
    end
  end
end
