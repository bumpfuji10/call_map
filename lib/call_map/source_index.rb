# frozen_string_literal: true

require_relative "definition_collector"

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

    # All :class definitions matching the qualified name (a class may be
    # reopened across files), in indexing order.
    def find_class_definitions(qualified_name)
      definitions.select { |d| d.kind == :class && d.name == qualified_name }
    end

    # The class plus its superclasses (innermost first), resolved against the
    # index. Stops at classes not present in the index or on a cycle.
    def ancestor_chain(owner)
      chain = []
      current = owner
      while current && !chain.include?(current)
        chain << current
        current = superclass_of(current)
      end
      chain
    end

    def superclass_of(owner)
      definition = find_class_definitions(owner).find(&:superclass)
      return nil unless definition

      superclass = definition.superclass
      # A "::"-prefixed superclass is an absolute path — no namespace fallback.
      return superclass.delete_prefix("::") if superclass.start_with?("::")

      resolve_class_name(superclass, definition.lexical_nesting)
    end

    private

    def find_method(kind, owner, name)
      definitions.reverse_each.find { |d| d.kind == kind && d.owner == owner && d.name == name.to_s }
    end

    # Resolve a superclass constant written relative to the subclass, mirroring
    # Ruby's lexical lookup: each enclosing scope (a full qualified name) from
    # innermost outward, then top-level.
    def resolve_class_name(name, nesting)
      (nesting || []).reverse_each do |scope|
        candidate = "#{scope}::#{name}"
        return candidate if find_class_definitions(candidate).any?
      end

      name
    end
  end
end
