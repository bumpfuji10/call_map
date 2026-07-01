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
    def initialize(receiver:, method_name:, line:, dynamic: false)
      @receiver = receiver
      @method_name = method_name
      @line = line
      @dynamic = dynamic
    end

    attr_reader :receiver, :method_name, :line

    def dynamic?
      @dynamic
    end

    def bare?
      receiver.nil?
    end

    # Human-readable label for tree output.
    def label
      base = receiver ? "#{receiver}.#{method_name}" : method_name
      dynamic? ? "#{base} [dynamic]" : base
    end
  end
end
