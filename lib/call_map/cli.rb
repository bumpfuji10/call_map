# frozen_string_literal: true

require "optparse"
require_relative "source_index"
require_relative "analyzer"
require_relative "formatters/text_tree"

module CallMap
  # Command-line entry point: parses the target and options, builds the
  # index, and prints the call tree.
  #
  #   call_map OrdersController#destroy --depth=3 --include-comments
  class CLI
    DEFAULT_DEPTH = 3

    def self.start(argv)
      new.start(argv)
    end

    def start(argv)
      options = parse_options!(argv)
      target = argv.first
      validate_target!(target)

      tree = build_tree(target, options)
      puts Formatters::TextTree.format(tree, include_comments: options.fetch(:include_comments, false))
    end

    private

    def build_tree(target, options)
      owner, method_name = target.split("#", 2)
      index = SourceIndex.build(root: options.fetch(:root, Dir.pwd))
      definition = index.find_instance_method(owner, method_name)
      abort "Error: definition not found for '#{target}'." unless definition

      Analyzer.new(index).build_call_tree(definition, depth: options.fetch(:depth, DEFAULT_DEPTH))
    end

    def parse_options!(argv)
      options = {}
      option_parser(options).parse!(argv)
      options
    rescue OptionParser::ParseError => e
      warn "Error: #{e.message}"
      exit 1
    end

    def option_parser(options)
      OptionParser.new do |opts|
        opts.on("--depth=N", Integer, "Maximum traversal depth (default: #{DEFAULT_DEPTH})") { |n| options[:depth] = n }
        opts.on("--include-comments", "Show method leading comments in the tree") { options[:include_comments] = true }
        opts.on("--root=PATH", "Application root to index (default: cwd)") { |path| options[:root] = path }
      end
    end

    def validate_target!(target)
      return if valid_class_name_method_format?(target)

      warn "Error: Invalid target format '#{target}'. Expected ClassName#method_name."
      exit 1
    end

    def valid_class_name_method_format?(target)
      /\A[A-Z][A-Za-z0-9_]*(::[A-Z][A-Za-z0-9_]*)*#[a-z_][A-Za-z0-9_]*[!?=]?\z/.match?(target)
    end
  end
end
