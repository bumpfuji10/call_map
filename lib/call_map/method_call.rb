# frozen_string_literal: true

module CallMap
  # A single method call extracted from a method body.
  #
  # This is a plain value object and must NOT depend on the parser (Prism).
  # Building a MethodCall from an AST is the job of CallExtractor.
  class MethodCall
    # Common Rails methods that appear as bare calls inside controllers and
    # models. A bare call that stays unresolved and matches this list is
    # displayed as a framework leaf.
    KNOWN_FRAMEWORK_METHODS = %w[
      redirect_to redirect_back render render_to_string head respond_to respond_with
      params request response session cookies flash logger helpers url_for
      current_user authenticate_user! sign_in sign_out authorize policy_scope
      raise puts pp
    ].freeze

    # @param receiver [String, nil] receiver expression ("OrderDeleteService", "self", nil for bare calls)
    # @param method_name [String] name of the called method
    # @param line [Integer] line number of the call site
    # @param dynamic [Boolean] true for send/public_send style calls
    # @param absolute [Boolean] true for ::Foo style absolute constant paths
    # @param callback [String, nil] callback type (e.g. "before_action") if this call originates from a DSL callback
    def initialize(receiver:, method_name:, line:, dynamic: false, absolute: false, callback: nil)
      @receiver = receiver
      @method_name = method_name
      @line = line
      @dynamic = dynamic
      @absolute = absolute
      @callback = callback
    end

    attr_reader :receiver, :method_name, :line, :callback

    def dynamic?
      @dynamic
    end

    def absolute?
      @absolute
    end

    def callback?
      !@callback.nil?
    end

    def bare?
      receiver.nil?
    end

    # Whether this call, IF it stays unresolved, should be shown as a
    # framework leaf. An explicit receiver that did not resolve points
    # outside the indexed app code; a bare call is framework-ish only when
    # it matches the known Rails method list (an unlisted bare call may just
    # be an analysis miss, so it gets no suffix rather than a wrong label).
    def framework_leaf?
      return false if dynamic? || callback?
      return KNOWN_FRAMEWORK_METHODS.include?(method_name) if bare?

      true
    end

    # Human-readable label for tree output.
    def label
      base = receiver ? "#{receiver}.#{method_name}" : method_name
      return "#{callback} #{base}" if callback?
      return "#{base} [dynamic]" if dynamic?

      base
    end
  end
end
