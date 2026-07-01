# frozen_string_literal: true

require "prism"
require_relative "call_extractor"
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
    def build_call_tree(definition, depth: 10)
      visited = Set.new
      build_node(definition, nil, depth, visited)
    end

    private

    def build_node(definition, method_call, remaining_depth, visited)
      key = node_key(definition)
      children = if remaining_depth.positive? && definition.method? && !visited.include?(key)
                   build_children(definition, remaining_depth, visited | [key])
                 else
                   []
                 end

      CallNode.new(definition: definition, method_call: method_call, children: children)
    end

    def build_children(definition, remaining_depth, visited)
      calls = extract_calls(definition)
      calls.map { |call| resolve_and_build(call, definition, remaining_depth, visited) }
    end

    def resolve_and_build(call, parent_definition, remaining_depth, visited)
      resolved = @resolver.resolve(call, context_owner: parent_definition.owner, context_kind: parent_definition.kind)

      if resolved
        build_node(resolved, call, remaining_depth - 1, visited)
      else
        CallNode.new(method_call: call)
      end
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
