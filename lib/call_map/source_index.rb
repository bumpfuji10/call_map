# frozen_string_literal: true

module CallMap
  # Ruby ファイル群から class / module / method 定義を索引化する。
  #
  # AST 処理は DefinitionCollector に委譲し、本クラスは Definition の保持と検索だけを担う。
  class SourceIndex
    DEFAULT_GLOB = "app/**/*.rb"

    # 指定ディレクトリ配下を索引化した SourceIndex を返す。
    def self.build(root:, glob: DEFAULT_GLOB)
      new.index_directory(root, glob: glob)
    end

    def initialize
      @definitions = []
    end

    attr_reader :definitions

    # @param root [String] 探索の起点ディレクトリ
    # @param glob [String] root からの相対 glob パターン
    def index_directory(root, glob: DEFAULT_GLOB)
      Dir.glob(File.join(root, glob)).each { |path| index_file(path) }
      self
    end

    def index_file(path)
      @definitions.concat(DefinitionCollector.collect(File.read(path), path: path))
      self
    end

    def classes
      definitions.select(&:class_or_module?)
    end

    def find_class(qualified_name)
      definitions.find { |d| d.class_or_module? && d.name == qualified_name }
    end

    def find_instance_method(owner, name)
      find_method(:instance_method, owner, name)
    end

    def find_class_method(owner, name)
      find_method(:class_method, owner, name)
    end

    private

    def find_method(kind, owner, name)
      definitions.find { |d| d.kind == kind && d.owner == owner && d.name == name.to_s }
    end
  end
end
