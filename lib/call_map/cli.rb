# frozen_string_literal: true

require "optparse"
require_relative "target"

module CallMap
  class CLI
    DEFAULT_DEPTH = 3

    def self.start(argv = ARGV)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv.dup
      @options = { depth: DEFAULT_DEPTH, root: Dir.pwd }
    end

    def run
      parser.parse!(@argv)
      target = parse_target!
      puts "#{target} (depth: #{@options[:depth]}, root: #{@options[:root]})"
      puts "[TODO] Analysis not yet implemented."
    rescue ArgumentError => e
      warn "Error: #{e.message}"
      exit 1
    end

    private

    def parse_target!
      target_str = @argv.shift
      if target_str.nil?
        warn "Error: target is required."
        warn ""
        warn parser
        exit 1
      end
      Target.parse!(target_str)
    end

    def parser
      @parser ||= build_parser
    end

    def build_parser # rubocop:disable Metrics/MethodLength
      OptionParser.new do |opts|
        opts.banner = "Usage: call_map ClassName#method_name [options]"
        opts.separator ""
        opts.separator "Options:"
        opts.on("--depth=N", Integer, "Max traversal depth (default: #{DEFAULT_DEPTH})") do |n|
          @options[:depth] = n
        end
        opts.on("--root=PATH", "Root directory of the Rails app (default: current directory)") do |path|
          @options[:root] = path
        end
        opts.on("-h", "--help", "Show this help") do
          puts opts
          exit
        end
      end
    end
  end
end
