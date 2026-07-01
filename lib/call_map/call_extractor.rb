# frozen_string_literal: true

require "prism"
require_relative "method_call"

module CallMap
  # Extracts method calls from a method body's AST.
  #
  # Like DefinitionCollector, this is a Prism boundary class — Prism node
  # types are referenced only here.
  class CallExtractor < Prism::Visitor
    DYNAMIC_METHODS = %w[send public_send __send__].freeze

    # Extract calls from a DefNode's body.
    #
    # @param def_node [Prism::DefNode] the method definition node
    # @return [Array<MethodCall>]
    def self.extract(def_node)
      extractor = new
      def_node.body&.accept(extractor)
      extractor.calls
    end

    def initialize
      super
      @calls = []
    end

    attr_reader :calls

    def visit_call_node(node)
      @calls << build_call(node)
      super
    end

    # Do not recurse into nested def bodies — they are not executed
    # as part of the enclosing method's call path.
    def visit_def_node(_node); end

    private

    def build_call(node)
      receiver_str = receiver_label(node.receiver)
      method_name = node.name.to_s
      dynamic = DYNAMIC_METHODS.include?(method_name)

      MethodCall.new(
        receiver: receiver_str,
        method_name: dynamic ? dynamic_target(node) : method_name,
        line: node.location.start_line,
        dynamic: dynamic
      )
    end

    def receiver_label(receiver)
      case receiver
      when nil then nil
      when Prism::SelfNode then "self"
      when Prism::ConstantReadNode, Prism::InstanceVariableReadNode
        receiver.name.to_s
      when Prism::ConstantPathNode then constant_path_name(receiver)
      when Prism::CallNode then call_chain_label(receiver)
      else "[expr]"
      end
    end

    def constant_path_name(node)
      parts = []
      current = node
      while current.is_a?(Prism::ConstantPathNode)
        parts.unshift(current.name.to_s)
        current = current.parent
      end
      parts.unshift(current.name.to_s) if current.is_a?(Prism::ConstantReadNode)
      parts.join("::")
    end

    def call_chain_label(node)
      receiver_str = receiver_label(node.receiver)
      method = node.name.to_s
      receiver_str ? "#{receiver_str}.#{method}" : method
    end

    # Best-effort extraction of the target method name from send/public_send.
    def dynamic_target(node)
      first_arg = node.arguments&.arguments&.first
      case first_arg
      when Prism::SymbolNode then first_arg.value
      when Prism::StringNode then first_arg.unescaped
      else "[dynamic]"
      end
    end
  end
end
