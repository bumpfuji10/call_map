# frozen_string_literal: true

module CallMap
  # A node in the call tree. Holds the definition (if resolved), the original
  # method call, and child nodes representing calls made from within this method.
  class CallNode
    # @param definition [Definition, nil] resolved definition, nil for unresolved leaves
    # @param method_call [MethodCall, nil] the call site that led here (nil for the root)
    # @param children [Array<CallNode>]
    def initialize(definition: nil, method_call: nil, children: [])
      @definition = definition
      @method_call = method_call
      @children = children
    end

    attr_reader :definition, :method_call, :children

    def resolved?
      !definition.nil?
    end

    # Human-readable label for this node.
    def label
      if definition
        definition.qualified_name
      elsif method_call
        method_call.label
      else
        "[unknown]"
      end
    end
  end
end
