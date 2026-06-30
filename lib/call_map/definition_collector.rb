# frozen_string_literal: true

require "prism"

module CallMap
  # Prism 固有の AST 処理を閉じ込める境界クラス。
  #
  # Prism の Node 種別（ClassNode / ModuleNode / DefNode など）に触れるのはこのクラスだけに
  # 限定し、他のコンポーネントは Definition だけを扱えるようにする。将来 parser gem などへ
  # 差し替える場合も、このクラスを置き換えれば済むようにする。
  class DefinitionCollector < Prism::Visitor
    def self.collect(source, path:)
      new(path).collect(source)
    end

    def initialize(path)
      super()
      @path = path
      @namespace = []
      @definitions = []
    end

    attr_reader :definitions

    # @param source [String] Ruby ソース
    # @return [Array<Definition>] 抽出した定義
    def collect(source)
      Prism.parse(source).value.accept(self)
      @definitions
    end

    def visit_class_node(node)
      within_namespace(constant_name(node.constant_path)) do
        @definitions << build_definition(:class, current_namespace, node)
        super
      end
    end

    def visit_module_node(node)
      within_namespace(constant_name(node.constant_path)) do
        @definitions << build_definition(:module, current_namespace, node)
        super
      end
    end

    def visit_def_node(node)
      if node.receiver.is_a?(Prism::SelfNode)
        # MVP では `def self.foo` 形式の class method 定義のみ扱う。
        @definitions << build_definition(:class_method, node.name.to_s, node, owner: current_namespace)
      elsif node.receiver.nil?
        @definitions << build_definition(:instance_method, node.name.to_s, node, owner: current_namespace)
      end
      super
    end

    private

    def build_definition(kind, name, node, owner: nil)
      Definition.new(kind: kind, name: name, owner: owner, path: @path, line: node.location.start_line)
    end

    def within_namespace(name)
      @namespace.push(name)
      yield
    ensure
      @namespace.pop
    end

    def current_namespace
      @namespace.join("::")
    end

    # 定数 Node から修飾名を組み立てる。
    # 例: `class Admin::OrdersController` -> "Admin::OrdersController"
    def constant_name(node)
      case node
      when Prism::ConstantReadNode
        node.name.to_s
      when Prism::ConstantPathNode
        [constant_name(node.parent), node.name.to_s].compact.join("::")
      end
    end
  end
end
