# frozen_string_literal: true

require "prism"
require "set" # rubocop:disable Lint/RedundantRequireStatement -- explicit for clarity; Set autoloads only on 3.2+
require_relative "call_extractor"
require_relative "callback_extractor"
require_relative "resolver"
require_relative "call_node"

module CallMap
  # Builds a call tree from a starting method definition by recursively
  # extracting calls and resolving them against the SourceIndex.
  class Analyzer
    # @param index [SourceIndex]
    def initialize(index)
      @index = index
      @resolver = Resolver.new(index)
    end

    # Build a call tree rooted at the given definition.
    #
    # @param definition [Definition] the starting method
    # @param depth [Integer] maximum recursion depth (0 = no children)
    # @return [CallNode]
    def build_call_tree(definition, depth: 3)
      visited = Set.new
      build_node(definition, nil, depth, visited, entry: true)
    end

    private

    def build_node(definition, method_call, remaining_depth, visited, entry: false)
      key = node_key(definition)
      children = if remaining_depth.positive? && definition.method? && !visited.include?(key)
                   build_children(definition, remaining_depth, visited | [key], entry: entry)
                 else
                   []
                 end

      CallNode.new(definition: definition, method_call: method_call, children: children)
    end

    def build_children(definition, remaining_depth, visited, entry: false)
      callback_nodes = entry ? build_callback_nodes(definition, remaining_depth, visited) : []
      call_nodes = extract_calls(definition).map do |call|
        resolve_and_build(call, definition, remaining_depth, visited)
      end
      callback_nodes + call_nodes
    end

    # Callbacks resolve against the class that declared them, so an inherited
    # `before_action :authenticate_user!` finds the parent's method.
    def build_callback_nodes(definition, remaining_depth, visited)
      extract_callbacks(definition).map do |call, declaring_owner|
        resolved = @resolver.resolve(call, context_owner: declaring_owner)
        build_resolved_node(resolved, call, remaining_depth, visited)
      end
    end

    def resolve_and_build(call, parent_definition, remaining_depth, visited)
      resolved = @resolver.resolve(call,
                                   context_owner: parent_definition.owner,
                                   context_kind: parent_definition.kind,
                                   lexical_nesting: parent_definition.lexical_nesting)
      build_resolved_node(resolved, call, remaining_depth, visited)
    end

    def build_resolved_node(resolved, call, remaining_depth, visited)
      if resolved
        build_node(resolved, call, remaining_depth - 1, visited)
      else
        CallNode.new(method_call: call)
      end
    end

    # Collect [callback, declaring_owner] pairs for the action, walking the
    # superclass chain so that parent-controller callbacks run first (as Rails does).
    def extract_callbacks(definition)
      return [] unless definition.kind == :instance_method

      ancestor_chain(definition.owner).reverse.flat_map do |owner|
        callbacks_declared_on(owner, definition.name).map { |call| [call, owner] }
      end
    end

    def callbacks_declared_on(owner, action_name)
      @index.find_class_definitions(owner).map(&:path).uniq.flat_map do |path|
        CallbackExtractor.extract(File.read(path), action_name, owner: owner)
      end
    end

    # The class plus its superclasses (innermost first), resolved via the
    # index. Stops at classes not present in the index or on a cycle.
    def ancestor_chain(owner)
      chain = []
      current = owner
      while current && !chain.include?(current)
        chain << current
        current = superclass_of(current)
      end
      chain
    end

    def superclass_of(owner)
      superclass = @index.find_class_definitions(owner).filter_map(&:superclass).first
      return nil unless superclass

      resolve_class_name(superclass, owner)
    end

    # Best-effort resolution of a superclass constant written relative to the
    # subclass: try the name as-is, then prefixed with the subclass namespace.
    def resolve_class_name(name, context_owner)
      return name if @index.find_class_definitions(name).any?

      namespace = context_owner.include?("::") ? context_owner.rpartition("::").first : nil
      return "#{namespace}::#{name}" if namespace && @index.find_class_definitions("#{namespace}::#{name}").any?

      name
    end

    def extract_calls(definition)
      source = File.read(definition.path)
      def_node = find_def_node(source, definition)
      return [] unless def_node

      CallExtractor.extract(def_node)
    end

    def find_def_node(source, definition)
      root = Prism.parse(source).value
      find_def_at_line(root, definition.name, definition.line)
    end

    def find_def_at_line(node, name, line)
      return node if node.is_a?(Prism::DefNode) && node.name.to_s == name && node.location.start_line == line

      node.child_nodes.compact.each do |child|
        result = find_def_at_line(child, name, line)
        return result if result
      end
      nil
    end

    def node_key(definition)
      "#{definition.path}:#{definition.line}:#{definition.qualified_name}"
    end
  end
end
