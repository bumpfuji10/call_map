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
    # @return [Array<Hash>] callback events in declaration order:
    #   { type: :add, call: MethodCall } for before_action,
    #   { type: :skip, name: String } for skip_before_action.
    #   Order matters — a callback re-added after a skip runs again.
    def self.extract(source, action_name, owner:)
      root = Prism.parse(source).value
      class_bodies = find_class_bodies(root, owner)
      return [] if class_bodies.empty?

      extractor = new(action_name)
      class_bodies.each { |body| body.accept(extractor) }
      extractor.events
    end

    # Collect ALL class bodies matching the owner (a class may be reopened
    # multiple times in the same file), in source order.
    def self.find_class_bodies(node, owner)
      collect_class_nodes(node, owner, []).filter_map(&:body)
    end

    def self.collect_class_nodes(node, owner, namespace)
      return collect_within_class_or_module(node, owner, namespace) if class_or_module?(node)

      node.child_nodes.compact.flat_map { |child| collect_class_nodes(child, owner, namespace) }
    end

    def self.class_or_module?(node)
      node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)
    end

    def self.collect_within_class_or_module(node, owner, namespace)
      qualified = build_qualified_name(node, namespace)
      matches = node.is_a?(Prism::ClassNode) && qualified == owner ? [node] : []

      body_children = (node.body&.child_nodes || []).compact
      matches + body_children.flat_map { |child| collect_class_nodes(child, owner, qualified.split("::")) }
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

    private_class_method :find_class_bodies, :collect_class_nodes, :class_or_module?,
                         :collect_within_class_or_module,
                         :build_qualified_name, :absolute_constant?, :already_qualified?,
                         :const_path_to_string, :full_constant_path

    def initialize(action_name)
      super()
      @action_name = action_name
      @events = []
    end

    attr_reader :events

    def visit_call_node(node)
      if node.name == :before_action && callback_applies?(node)
        extract_callback_names(node).each do |name|
          call = MethodCall.new(receiver: nil, method_name: name, line: node.location.start_line,
                                callback: "before_action")
          @events << { type: :add, call: call }
        end
      elsif node.name == :skip_before_action && callback_applies?(node)
        extract_callback_names(node).each { |name| @events << { type: :skip, name: name } }
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
      # Options arrive as a KeywordHashNode (`only: :show`) or a HashNode
      # when written with explicit braces (`{ only: :show }`).
      options = node.arguments&.arguments&.find do |a|
        a.is_a?(Prism::KeywordHashNode) || a.is_a?(Prism::HashNode)
      end
      return nil unless options

      assoc = scope_assoc(options)
      assoc && [assoc.key.value, assoc.value]
    end

    def scope_assoc(keyword_hash)
      keyword_hash.elements.find do |el|
        el.is_a?(Prism::AssocNode) && el.key.is_a?(Prism::SymbolNode) && %w[only except].include?(el.key.value)
      end
    end

    def action_in_list?(value_node)
      case value_node
      when Prism::ArrayNode
        value_node.elements.any? { |el| action_name_matches?(el) }
      else
        action_name_matches?(value_node)
      end
    end

    def action_name_matches?(node)
      case node
      when Prism::SymbolNode then node.value == @action_name
      when Prism::StringNode then node.unescaped == @action_name
      else false
      end
    end
  end
end
