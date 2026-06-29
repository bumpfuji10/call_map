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
      puts target
    end
  end
end

