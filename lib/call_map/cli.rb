# CLIクライアント
require "optparse"

module CallMap 
  class CLI
    def self.start(argv)
      options = {}

      opt = OptionParser.new do |opts|
        opts.on("--depth=N", Integer) do |n|
          options[:depth] = n
        end
      end 
      opt.parse!(argv)
      target = argv.first
      if valid_class_name_method_format?(target)
        puts "[TODO] Analysis not yet implemented."
      else
        warn "Error: Invalid target format '#{target}'. Expected ClassName#method_name."
        exit 1
      end
    end
    
    def self.valid_class_name_method_format?(target)
      /\A[A-Z][A-Za-z0-9_]*(::[A-Z][A-Za-z0-9_]*)*#[a-z][A-Za-z0-9_]*[!?=]?\z/.match?(target)
    end
  end
end

