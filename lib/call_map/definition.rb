# frozen_string_literal: true

module CallMap
  # class / module / method の定義1件を表す値オブジェクト。
  #
  # parser gem 固有の AST には依存しない。AST から本オブジェクトを組み立てる責務は
  # DefinitionCollector に閉じ込める。
  class Definition
    KINDS = %i[class module instance_method class_method].freeze

    # @param kind [Symbol] KINDS のいずれか
    # @param name [String] kind が class/module なら修飾済み定数名、method なら method 名
    # @param path [String] 定義が書かれたファイルパス
    # @param line [Integer] 定義の開始行番号
    # @param owner [String, nil] method の場合、所属する class/module の修飾済み定数名
    def initialize(kind:, name:, path:, line:, owner: nil)
      raise ArgumentError, "unknown kind: #{kind}" unless KINDS.include?(kind)

      @kind = kind
      @name = name
      @owner = owner
      @path = path
      @line = line
      # method 直上コメントなどを後続 issue で格納するための枠。
      @metadata = {}
    end

    attr_reader :kind, :name, :owner, :path, :line
    attr_accessor :metadata

    def class_or_module?
      %i[class module].include?(kind)
    end

    def method?
      %i[instance_method class_method].include?(kind)
    end

    def instance_method?
      kind == :instance_method
    end

    def class_method?
      kind == :class_method
    end

    # 検索やツリー表示で使う、人間可読な修飾名。
    #
    # - class / module: "Admin::OrdersController"
    # - instance method: "OrdersController#destroy"
    # - class method: "OrderDeleteService.execute"
    def qualified_name
      case kind
      when :instance_method then "#{owner}##{name}"
      when :class_method then "#{owner}.#{name}"
      else name
      end
    end

    def ==(other)
      other.is_a?(Definition) &&
        kind == other.kind &&
        name == other.name &&
        owner == other.owner &&
        path == other.path &&
        line == other.line
    end
    alias eql? ==

    def hash
      [kind, name, owner, path, line].hash
    end
  end
end
