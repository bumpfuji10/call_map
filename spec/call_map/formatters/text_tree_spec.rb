# frozen_string_literal: true

require "spec_helper"

RSpec.describe CallMap::Formatters::TextTree do
  let(:fixture_root) { File.expand_path("../../fixtures/rails_app", __dir__) }
  let(:index) { CallMap::SourceIndex.build(root: fixture_root) }
  let(:analyzer) { CallMap::Analyzer.new(index) }

  def format_tree_for(owner, method_name, kind: :instance_method)
    definition = if kind == :instance_method
                   index.find_instance_method(owner, method_name)
                 else
                   index.find_class_method(owner, method_name)
                 end
    described_class.format(analyzer.build_call_tree(definition))
  end

  describe ".format" do
    it "renders the full MVP path for OrdersController#destroy" do
      expected = <<~TREE
        OrdersController#destroy
        ├─ before_action authenticate_user!
        ├─ before_action authenticate
        ├─ before_action set_order
        │  ├─ Order.find
        │  └─ params.[]
        ├─ authorize
        ├─ OrderDeleteService.execute
        │  └─ OrderDeleteService#execute
        │     └─ @order.destroy!
        └─ OrderNotifier.notify_deletion
           └─ OrderNotifier#send_notification
              ├─ OrderNotifier#deliver
              └─ @order.user
      TREE

      expect(format_tree_for("OrdersController", "destroy")).to eq(expected)
    end

    it "renders a class-method rooted tree" do
      expected = <<~TREE
        OrderDeleteService.execute
        └─ OrderDeleteService#execute
           └─ @order.destroy!
      TREE

      expect(format_tree_for("OrderDeleteService", "execute", kind: :class_method)).to eq(expected)
    end

    it "renders circular revisits with the [circular] marker" do
      expected = <<~TREE
        CircularService#ping
        └─ CircularService#pong
           └─ CircularService#ping [circular]
      TREE

      expect(format_tree_for("CircularService", "ping")).to eq(expected)
    end

    it "renders a leaf-only tree as just the root label" do
      definition = index.find_instance_method("OrdersController", "destroy")
      tree = analyzer.build_call_tree(definition, depth: 0)

      expect(described_class.format(tree)).to eq("OrdersController#destroy\n")
    end

    it "produces identical output across repeated runs" do
      first = format_tree_for("OrdersController", "destroy")

      fresh_index = CallMap::SourceIndex.build(root: fixture_root)
      fresh_analyzer = CallMap::Analyzer.new(fresh_index)
      definition = fresh_index.find_instance_method("OrdersController", "destroy")
      second = described_class.format(fresh_analyzer.build_call_tree(definition))

      expect(second).to eq(first)
    end
  end
end
