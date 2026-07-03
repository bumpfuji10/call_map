# frozen_string_literal: true

module CallMap
  # A single method call extracted from a method body.
  #
  # This is a plain value object and must NOT depend on the parser (Prism).
  # Building a MethodCall from an AST is the job of CallExtractor.
  class MethodCall
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

    # Human-readable label for tree output.
    def label
      base = receiver ? "#{receiver}.#{method_name}" : method_name
      return "#{callback} #{base}" if callback?
      return "#{base} [dynamic]" if dynamic?

      base
    end
  end
end
