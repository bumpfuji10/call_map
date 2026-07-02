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
      find_class_node(node, owner, [])&.body
    end

    def self.find_class_node(node, owner, namespace)
      return search_within_class_or_module(node, owner, namespace) if class_or_module?(node)

      search_children(node, owner, namespace)
    end

    def self.class_or_module?(node)
      node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)
    end

    def self.search_within_class_or_module(node, owner, namespace)
      qualified = build_qualified_name(node, namespace)
      return node if node.is_a?(Prism::ClassNode) && qualified == owner

      body_children = node.body&.child_nodes || []
      body_children.compact.each do |child|
        result = find_class_node(child, owner, qualified.split("::"))
        return result if result
      end
      nil
    end

    def self.search_children(node, owner, namespace)
      node.child_nodes.compact.each do |child|
        result = find_class_node(child, owner, namespace)
        return result if result
      end
      nil
    end

    def self.build_qualified_name(node, namespace)
      const = node.constant_path
      return const_path_to_string(const) if namespace.empty? || absolute_constant?(const)

      name = const_path_to_string(const)
      return name if already_qualified?(name, namespace)

      "#{namespace.join('::')}::#{name}"
    end

    def self.absolute_constant?(const)
      return false unless const.is_a?(Prism::ConstantPathNode)

      current = const
      current = current.parent while current.is_a?(Prism::ConstantPathNode)
      current.nil?
    end

    def self.already_qualified?(name, namespace)
      prefix = namespace.join("::")
      name == prefix || name.start_with?("#{prefix}::")
    end

    def self.const_path_to_string(const)
      case const
      when Prism::ConstantReadNode then const.name.to_s
      when Prism::ConstantPathNode then full_constant_path(const)
      else const.to_s
      end
    end

    def self.full_constant_path(node)
      parts = []
      current = node
      while current.is_a?(Prism::ConstantPathNode)
        parts.unshift(current.name.to_s)
        current = current.parent
      end
      parts.unshift(current.name.to_s) if current.is_a?(Prism::ConstantReadNode)
      parts.join("::")
    end

    private_class_method :find_class_body, :find_class_node, :class_or_module?,
                         :search_within_class_or_module, :search_children,
                         :build_qualified_name, :absolute_constant?, :already_qualified?,
                         :const_path_to_string, :full_constant_path

    def initialize(action_name)
      super()
      @action_name = action_name
      @callbacks = []
    end

    attr_reader :callbacks

    def visit_call_node(node)
      if node.name == :before_action && callback_applies?(node)
        extract_callback_names(node).each do |name|
          @callbacks << MethodCall.new(receiver: nil, method_name: name, line: node.location.start_line,
                                       callback: "before_action")
        end
      end
      super
    end

    # Callbacks belong to the class they are declared in — do not descend into
    # nested classes/modules or method bodies within the target class body.
    def visit_class_node(_node); end
    def visit_module_node(_node); end
    def visit_singleton_class_node(_node); end
    def visit_def_node(_node); end

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
