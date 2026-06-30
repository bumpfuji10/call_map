# frozen_string_literal: true

module CallMap
  # Indexes class / module / method definitions found under a directory.
  #
  # AST handling is delegated to DefinitionCollector; this class only stores
  # the resulting Definitions and answers lookups against them.
  class SourceIndex
    DEFAULT_GLOB = "app/**/*.rb"

    # Build a SourceIndex by indexing every Ruby file under `root`.
    def self.build(root:, glob: DEFAULT_GLOB)
      new.index_directory(root, glob: glob)
    end

    def initialize
      @definitions = []
    end

    attr_reader :definitions

    # @param root [String] directory to search from
    # @param glob [String] glob pattern relative to root
    def index_directory(root, glob: DEFAULT_GLOB)
      Dir.glob(File.join(root, glob)).each { |path| index_file(path) }
      self
    end

    def index_file(path)
      @definitions.concat(DefinitionCollector.collect(File.read(path), path: path))
      self
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
