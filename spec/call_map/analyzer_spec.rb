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

      it "includes all before_action callbacks as children" do
        callback_names = tree.children.map { |c| c.method_call&.method_name }
        expect(callback_names).to include("authenticate")
        expect(callback_names).to include("set_order")
      end

      it "resolves set_order callback to the instance method" do
        set_order = tree.children.find { |c| c.method_call&.method_name == "set_order" }

        expect(set_order).to be_resolved
        expect(set_order.definition.kind).to eq(:instance_method)
      end

      it "labels callback calls with before_action prefix" do
        set_order = tree.children.find { |c| c.method_call&.method_name == "set_order" }

        expect(set_order.method_call).to be_callback
        expect(set_order.method_call.label).to eq("before_action set_order")
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

    context "resolving self.new.perform in a class method" do
      let(:definition) { index.find_class_method("SelfNewService", "execute") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "resolves self.new.perform to the instance method" do
        child = tree.children.find { |c| c.method_call&.method_name == "perform" }

        expect(child).not_to be_nil
        expect(child).to be_resolved
        expect(child.definition.kind).to eq(:instance_method)
        expect(child.definition.qualified_name).to eq("SelfNewService#perform")
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

    context "bare calls inside a class method resolve to class methods" do
      let(:definition) { index.find_class_method("ClassMethodCallerService", "execute") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "resolves validate to the class method, not the instance method" do
        child = tree.children.find { |c| c.method_call&.method_name == "validate" }

        expect(child).not_to be_nil
        expect(child).to be_resolved
        expect(child.definition.kind).to eq(:class_method)
      end
    end

    context "dynamic calls remain as leaf nodes" do
      let(:definition) { index.find_class_method("DynamicDispatchService", "execute") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "does not resolve send(:perform) to the instance method" do
        send_node = tree.children.find { |c| c.method_call&.dynamic? }

        expect(send_node).not_to be_nil
        expect(send_node).not_to be_resolved
      end
    end

    context "shared method across branches expands in both" do
      let(:definition) { index.find_instance_method("SharedCallService", "entry") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "expands shared_helper under both branch_a and branch_b" do
        branch_a = tree.children.find { |c| c.method_call&.method_name == "branch_a" }
        branch_b = tree.children.find { |c| c.method_call&.method_name == "branch_b" }

        expect(branch_a.children.map { |c| c.method_call&.method_name }).to include("shared_helper")
        expect(branch_b.children.map { |c| c.method_call&.method_name }).to include("shared_helper")

        helper_a = branch_a.children.find { |c| c.method_call&.method_name == "shared_helper" }
        helper_b = branch_b.children.find { |c| c.method_call&.method_name == "shared_helper" }

        expect(helper_a).to be_resolved
        expect(helper_b).to be_resolved
      end
    end

    context "self.helper in instance method resolves to instance method" do
      let(:definition) { index.find_instance_method("SelfCallService", "run") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "resolves self.helper to the instance method, not the class method" do
        child = tree.children.find { |c| c.method_call&.method_name == "helper" }

        expect(child).not_to be_nil
        expect(child).to be_resolved
        expect(child.definition.kind).to eq(:instance_method)
      end
    end

    context "compact-style class with before_action" do
      let(:definition) { index.find_instance_method("Admin::DashboardController", "show") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "includes before_action from compact-style class without double-prefixing" do
        callback = tree.children.find { |c| c.method_call&.method_name == "require_admin" }

        expect(callback).not_to be_nil
        expect(callback).to be_resolved
      end
    end

    context "namespace-relative constant resolution" do
      let(:definition) { index.find_instance_method("Reports::ReportRunner", "run") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "resolves Generator.build to Reports::Generator.build" do
        child = tree.children.find { |c| c.method_call&.method_name == "build" }

        expect(child).not_to be_nil
        expect(child).to be_resolved
        expect(child.definition.owner).to eq("Reports::Generator")
      end
    end

    context "absolute constant skips namespace fallback" do
      let(:definition) { index.find_instance_method("Reports::AbsoluteCaller", "run") }
      let(:tree) { analyzer.build_call_tree(definition) }

      it "resolves ::TopLevelService.execute without namespace prefix" do
        child = tree.children.find { |c| c.method_call&.method_name == "execute" }

        expect(child).not_to be_nil
        expect(child.method_call).to be_absolute
        expect(child).not_to be_resolved
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
