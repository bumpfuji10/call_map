# frozen_string_literal: true

module CallMap
  # A node in the call tree. Holds the definition (if resolved), the original
  # method call, and child nodes representing calls made from within this method.
  class CallNode
    # @param definition [Definition, nil] resolved definition, nil for unresolved leaves
    # @param method_call [MethodCall, nil] the call site that led here (nil for the root)
    # @param children [Array<CallNode>]
    # @param circular [Boolean] true when this node revisits a definition already on the current path
    def initialize(definition: nil, method_call: nil, children: [], circular: false)
      @definition = definition
      @method_call = method_call
      @children = children
      @circular = circular
    end

    attr_reader :definition, :method_call, :children

    def resolved?
      !definition.nil?
    end

    def circular?
      @circular
    end

    # Human-readable label for this node. A callback-originated node keeps its
    # callback label (e.g. "before_action set_order") even when resolved, so
    # tree output can distinguish it from a plain call. An unresolved call
    # that points outside the indexed app code is marked as a framework leaf.
    def label
      base = base_label
      return "#{base} [circular]" if circular?
      return "#{base} [framework]" if !resolved? && method_call&.framework_leaf?

      base
    end

    private

    def base_label
      if definition && !method_call&.callback?
        definition.qualified_name
      elsif method_call
        method_call.label
      else
        "[unknown]"
      end
    end
  end
end
