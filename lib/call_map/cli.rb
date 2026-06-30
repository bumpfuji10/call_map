# frozen_string_literal: true

# CLIクライアント
require "optparse"

module CallMap
  class CLI
    def self.start(argv)
      parse_options!(argv)
      target = argv.first
      validate_target!(target)
      puts "[TODO] Analysis not yet implemented."
    end

    def self.parse_options!(argv)
      options = {}
      OptionParser.new do |opts|
        opts.on("--depth=N", Integer) do |n|
          options[:depth] = n
        end
      end.parse!(argv)
      options
    rescue OptionParser::ParseError => e
      warn "Error: #{e.message}"
      exit 1
    end

    def self.validate_target!(target)
      return if valid_class_name_method_format?(target)

      warn "Error: Invalid target format '#{target}'. Expected ClassName#method_name."
      exit 1
    end

    def self.valid_class_name_method_format?(target)
      /\A[A-Z][A-Za-z0-9_]*(::[A-Z][A-Za-z0-9_]*)*#[a-z][A-Za-z0-9_]*[!?=]?\z/.match?(target)
    end
  end
end
