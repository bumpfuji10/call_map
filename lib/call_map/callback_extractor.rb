# frozen_string_literal: true

require "prism"
require_relative "method_call"

module CallMap
  # Extracts before_action callbacks from a class body that apply to a given action.
  #
  # This is a Prism boundary class — Prism node types are referenced only here.
  class CallbackExtractor < Prism::Visitor
    # @param source [String] the file source
    # @param action_name [String] the action method name
    # @param owner [String] the class name to scope extraction to
    # @return [Array<MethodCall>]
    def self.extract(source, action_name, owner:)
      root = Prism.parse(source).value
      class_body = find_class_body(root, owner)
      return [] unless class_body

      extractor = new(action_name)
      class_body.accept(extractor)
      extractor.callbacks
    end

    def self.find_class_body(node, owner)
      target = owner.split("::").last
      find_class_node(node, target)&.body
    end

    def self.find_class_node(node, name)
      return node if class_node_matches?(node, name)

      node.child_nodes.compact.each do |child|
        result = find_class_node(child, name)
        return result if result
      end
      nil
    end

    def self.class_node_matches?(node, name)
      return false unless node.is_a?(Prism::ClassNode)

      const = node.constant_path
      const_name = const.name.to_s if const.is_a?(Prism::ConstantReadNode) || const.is_a?(Prism::ConstantPathNode)
      const_name == name
    end

    private_class_method :find_class_body, :find_class_node

    def initialize(action_name)
      super()
      @action_name = action_name
      @callbacks = []
    end

    attr_reader :callbacks

    def visit_call_node(node)
      if node.name == :before_action && callback_applies?(node)
        extract_callback_names(node).each do |name|
          @callbacks << MethodCall.new(receiver: nil, method_name: name, line: node.location.start_line)
        end
      end
      super
    end

    private

    def extract_callback_names(node)
      return [] unless node.arguments

      node.arguments.arguments.filter_map do |arg|
        arg.value if arg.is_a?(Prism::SymbolNode)
      end
    end

    def callback_applies?(node)
      filter = find_scope_filter(node)
      return true unless filter

      key, value = filter
      key == "only" ? action_in_list?(value) : !action_in_list?(value)
    end

    def find_scope_filter(node)
      keyword_hash = node.arguments&.arguments&.find { |a| a.is_a?(Prism::KeywordHashNode) }
      return nil unless keyword_hash

      assoc = scope_assoc(keyword_hash)
      assoc && [assoc.key.value, assoc.value]
    end

    def scope_assoc(keyword_hash)
      keyword_hash.elements.find do |el|
        el.is_a?(Prism::AssocNode) && el.key.is_a?(Prism::SymbolNode) && %w[only except].include?(el.key.value)
      end
    end

    def action_in_list?(value_node)
      case value_node
      when Prism::SymbolNode
        value_node.value == @action_name
      when Prism::ArrayNode
        value_node.elements.any? { |el| el.is_a?(Prism::SymbolNode) && el.value == @action_name }
      else
        false
      end
    end
  end
end
