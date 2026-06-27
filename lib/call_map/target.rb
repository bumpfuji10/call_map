# frozen_string_literal: true

module CallMap
  class Target
    PATTERN = /\A([A-Z][A-Za-z0-9:]*)[#.]([a-z_][a-zA-Z0-9_]*[?!]?)\z/

    attr_reader :class_name, :method_name

    def self.parse!(str)
      match = PATTERN.match(str)
      unless match
        raise ArgumentError,
              "Invalid target '#{str}'. Expected ClassName#method_name or ClassName.method_name."
      end

      new(class_name: match[1], method_name: match[2], instance_method: str.include?("#"))
    end

    def initialize(class_name:, method_name:, instance_method:)
      @class_name = class_name
      @method_name = method_name
      @instance_method = instance_method
    end

    def instance_method?
      @instance_method
    end

    def to_s
      sep = instance_method? ? "#" : "."
      "#{class_name}#{sep}#{method_name}"
    end
  end
end
