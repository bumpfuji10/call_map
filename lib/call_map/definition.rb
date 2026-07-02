# frozen_string_literal: true

module CallMap
  # A single class / module / method definition.
  #
  # This is a plain value object and must NOT depend on the parser (Prism).
  # Building a Definition from an AST is the job of the parser boundary class,
  # so that parser-specific code stays in one place.
  class Definition
    KINDS = %i[class module instance_method class_method].freeze

    # @param kind [Symbol] one of KINDS
    # @param name [String] method name, or qualified constant name for class/module
    # @param path [String] file path where the definition is written
    # @param line [Integer] starting line number of the definition
    # @param owner [String, nil] qualified constant name of the enclosing class/module (for methods)
    # @param lexical_nesting [Array<String>, nil] lexical scope stack at the definition site, outermost first
    # @param superclass [String, nil] superclass constant name as written (for :class definitions)
    def initialize(kind:, name:, path:, line:, owner: nil, lexical_nesting: nil, superclass: nil)
      raise ArgumentError, "unknown kind: #{kind}" unless KINDS.include?(kind)

      @kind = kind
      @name = name
      @owner = owner
      @path = path
      @line = line
      @lexical_nesting = lexical_nesting
      @superclass = superclass
      # Placeholder for method-leading comments etc., to be filled by a later issue.
      @metadata = {}
    end

    attr_reader :kind, :name, :owner, :path, :line, :lexical_nesting, :superclass
    attr_accessor :metadata

    def class_or_module?
      %i[class module].include?(kind)
    end

    def method?
      %i[instance_method class_method].include?(kind)
    end

    # Human-readable qualified name used for lookups and tree output.
    #
    # - class / module:    "Admin::ReportsController"
    # - instance method:   "OrdersController#destroy"
    # - class method:      "OrderDeleteService.execute"
    def qualified_name
      case kind
      when :instance_method then "#{owner}##{name}"
      when :class_method then "#{owner}.#{name}"
      else name
      end
    end
  end
end
