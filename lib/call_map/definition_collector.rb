# frozen_string_literal: true

require "prism"

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
      @singletons = []       # per-scope flag: are we inside `class << self`?
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
      within_namespace(constant_name(node.constant_path)) do
        @definitions << build_definition(:class, current_namespace, node)
        super # descend into the class body (its methods etc.)
      end
    end

    # Called when the traversal reaches a `module` definition.
    def visit_module_node(node)
      within_namespace(constant_name(node.constant_path)) do
        @definitions << build_definition(:module, current_namespace, node)
        super
      end
    end

    # Called for `class << self` (and `class << obj`).
    def visit_singleton_class_node(node)
      # Only `class << self` reliably maps to the enclosing class; treat its
      # bodyless `def`s as class methods. `class << obj` can't be resolved
      # statically, so don't claim those as class methods.
      within_singleton(node.expression.is_a?(Prism::SelfNode)) do
        super
      end
    end

    # Called for every `def` — `def foo`, `def self.foo`, and `def Foo.bar`.
    def visit_def_node(node)
      kind, owner = method_kind_and_owner(node.receiver)
      @definitions << build_definition(kind, node.name.to_s, node, owner: owner)
      super
    end

    private

    # Decide the (kind, owner) of a method from its `def` receiver.
    # - no receiver        (`def foo`)        -> instance method, unless inside
    #                                            `class << self`, where it is a class method
    # - self receiver      (`def self.foo`)   -> class method on the current namespace
    # - constant receiver  (`def Foo.bar`)    -> class method owned by that constant
    def method_kind_and_owner(receiver)
      case receiver
      when nil
        [singleton_self? ? :class_method : :instance_method, current_namespace]
      when Prism::SelfNode
        [:class_method, current_namespace]
      else
        [:class_method, constant_name(receiver)]
      end
    end

    def build_definition(kind, name, node, owner: nil)
      Definition.new(kind: kind, name: name, owner: owner, path: @path, line: node.location.start_line)
    end

    # Push `name` while the block runs, then always pop it back off.
    # Entering a named class/module also resets the singleton flag, so a normal
    # class nested inside `class << self` is not mistaken for a singleton scope.
    def within_namespace(name)
      @namespace.push(name)
      @singletons.push(false)
      yield
    ensure
      @namespace.pop
      @singletons.pop
    end

    # Track whether the current scope is a `class << self` body.
    def within_singleton(is_self)
      @singletons.push(is_self)
      yield
    ensure
      @singletons.pop
    end

    def singleton_self?
      @singletons.last == true
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
