# frozen_string_literal: true

require "spec_helper"

RSpec.describe CallMap::Analyzer do
  let(:fixture_root) { File.expand_path("../fixtures/rails_app", __dir__) }
  let(:index) { CallMap::SourceIndex.build(root: fixture_root) }
  subject(:analyzer) { described_class.new(index) }

  describe "#build_call_tree" do
    context "from OrdersController#destroy" do
      let(:definition) { index.find_instance_method("OrdersController", "destroy") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "returns a CallNode rooted at the definition" do
        expect(tree).to be_a(CallMap::CallNode)
        expect(tree.label).to eq("OrdersController#destroy")
      end

      it "has children for the calls in destroy" do
        labels = tree.children.map(&:label)
        expect(labels).to include("OrderDeleteService.execute")
        expect(labels).to include("OrderNotifier.notify_deletion")
      end

      it "resolves OrderDeleteService.execute to the class method definition" do
        child = tree.children.find { |c| c.label == "OrderDeleteService.execute" }

        expect(child).to be_resolved
        expect(child.definition.kind).to eq(:class_method)
      end

      it "keeps unresolved calls as leaf nodes" do
        authorize = tree.children.find { |c| c.method_call&.method_name == "authorize" }

        expect(authorize).not_to be_nil
        expect(authorize).not_to be_resolved
      end
    end

    context "resolving SomeClass.new(...).execute to an instance method" do
      let(:definition) { index.find_class_method("OrderDeleteService", "execute") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "resolves new(...).execute to the instance method" do
        child = tree.children.find { |c| c.method_call&.method_name == "execute" }

        expect(child).not_to be_nil
        expect(child).to be_resolved
        expect(child.definition.kind).to eq(:instance_method)
        expect(child.definition.qualified_name).to eq("OrderDeleteService#execute")
      end
    end

    context "resolving same-class private methods" do
      let(:definition) { index.find_instance_method("OrdersController", "show") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "keeps authorize as an unresolved leaf (framework call)" do
        authorize = tree.children.find { |c| c.method_call&.method_name == "authorize" }

        expect(authorize).not_to be_nil
        expect(authorize).not_to be_resolved
      end
    end

    context "with OrderNotifier.notify_deletion" do
      let(:definition) { index.find_class_method("OrderNotifier", "notify_deletion") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "resolves bare calls within the same class as instance methods" do
        child = tree.children.find { |c| c.method_call&.method_name == "send_notification" }

        expect(child).not_to be_nil
        expect(child).to be_resolved
        expect(child.definition.kind).to eq(:instance_method)
      end
    end

    context "circular call protection" do
      it "does not recurse infinitely on circular calls" do
        expect { analyzer.build_call_tree(index.find_instance_method("OrdersController", "destroy")) }
          .not_to raise_error
      end
    end

    context "depth limiting" do
      let(:definition) { index.find_instance_method("OrdersController", "destroy") }

      it "stops recursion at the specified depth" do
        tree = analyzer.build_call_tree(definition, depth: 0)

        expect(tree.children).to eq([])
      end
    end
  end
end
