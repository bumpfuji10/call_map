# frozen_string_literal: true

require "spec_helper"
require "call_map/cli"

RSpec.describe CallMap::CLI do
  let(:fixture_root) { File.expand_path("../fixtures/rails_app", __dir__) }

  def run_cli(*argv)
    output = StringIO.new
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = output
    $stderr = StringIO.new
    described_class.start(argv)
    output.string
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end

  describe ".start" do
    it "prints a shallower tree with --depth=1" do
      output = run_cli("OrdersController#destroy", "--depth=1", "--root=#{fixture_root}")

      expect(output).to include("├─ OrderDeleteService.execute")
      expect(output).not_to include("OrderDeleteService#execute")
    end

    it "prints a deeper tree with --depth=3" do
      output = run_cli("OrdersController#destroy", "--depth=3", "--root=#{fixture_root}")

      expect(output).to include("OrderDeleteService#execute")
      expect(output).to include("@order.destroy! [framework]")
    end

    it "defaults to depth #{described_class::DEFAULT_DEPTH}" do
      explicit = run_cli("OrdersController#destroy", "--depth=#{described_class::DEFAULT_DEPTH}",
                         "--root=#{fixture_root}")
      default = run_cli("OrdersController#destroy", "--root=#{fixture_root}")

      expect(default).to eq(explicit)
    end

    it "shows leading comments with --include-comments" do
      output = run_cli("CommentedService#call", "--include-comments", "--root=#{fixture_root}")

      expect(output).to include("# Entry point. Validates input and delegates to the worker.")
    end

    it "rejects an invalid target format" do
      expect { run_cli("not-a-target", "--root=#{fixture_root}") }
        .to raise_error(SystemExit)
    end

    it "aborts when the target definition is not found" do
      expect { run_cli("NoSuchController#index", "--root=#{fixture_root}") }
        .to raise_error(SystemExit)
    end
  end
end
