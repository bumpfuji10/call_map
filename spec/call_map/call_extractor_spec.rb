# frozen_string_literal: true

require "spec_helper"

RSpec.describe CallMap::CallExtractor do
  # Parse source and find the DefNode for the given method name.
  def def_node_for(source, method_name)
    root = Prism.parse(source).value
    find_def(root, method_name)
  end

  def find_def(node, method_name)
    return node if node.is_a?(Prism::DefNode) && node.name.to_s == method_name

    node.child_nodes.compact.each do |child|
      result = find_def(child, method_name)
      return result if result
    end
    nil
  end

  let(:fixture_root) { File.expand_path("../fixtures/rails_app", __dir__) }

  describe ".extract" do
    context "with OrdersController#destroy" do
      let(:source) { File.read(File.join(fixture_root, "app/controllers/orders_controller.rb")) }
      let(:calls) { described_class.extract(def_node_for(source, "destroy")) }

      it "extracts authorize as a bare method call" do
        call = calls.find { |c| c.method_name == "authorize" }

        expect(call).not_to be_nil
        expect(call.receiver).to be_nil
        expect(call).to be_bare
      end

      it "extracts OrderDeleteService.execute with a constant receiver" do
        call = calls.find { |c| c.method_name == "execute" && c.receiver == "OrderDeleteService" }

        expect(call).not_to be_nil
        expect(call.receiver).to eq("OrderDeleteService")
        expect(call.label).to eq("OrderDeleteService.execute")
      end

      it "extracts OrderNotifier.notify_deletion with a constant receiver" do
        call = calls.find { |c| c.method_name == "notify_deletion" }

        expect(call).not_to be_nil
        expect(call.receiver).to eq("OrderNotifier")
        expect(call.label).to eq("OrderNotifier.notify_deletion")
      end

      it "returns MethodCall objects, not AST nodes" do
        calls.each do |call|
          expect(call).to be_a(CallMap::MethodCall)
        end
      end
    end

    context "with dynamic calls" do
      let(:source) do
        <<~RUBY
          class Foo
            def bar
              send(:hello)
              public_send(:world, 1, 2)
              __send__(:secret)
              send(method_name)
            end
          end
        RUBY
      end
      let(:calls) { described_class.extract(def_node_for(source, "bar")) }

      it "marks send/public_send/__send__ as dynamic" do
        dynamic_calls = calls.select(&:dynamic?)
        expect(dynamic_calls.size).to eq(4)
      end

      it "extracts the symbol target from send(:hello)" do
        call = calls.find { |c| c.method_name == "hello" }

        expect(call).not_to be_nil
        expect(call).to be_dynamic
        expect(call.label).to eq("hello [dynamic]")
      end

      it "falls back to [dynamic] when target is not a literal" do
        call = calls.find { |c| c.method_name == "[dynamic]" }

        expect(call).not_to be_nil
        expect(call).to be_dynamic
      end
    end

    context "with a call chain (SomeClass.new.execute)" do
      let(:source) do
        <<~RUBY
          class Foo
            def bar
              OrderDeleteService.new(build_order).execute
            end
          end
        RUBY
      end
      let(:calls) { described_class.extract(def_node_for(source, "bar")) }

      it "labels the outer call with the full chain as receiver" do
        call = calls.find { |c| c.method_name == "execute" }

        expect(call).not_to be_nil
        expect(call.receiver).to eq("OrderDeleteService.new")
        expect(call.label).to eq("OrderDeleteService.new.execute")
      end

      it "does not extract the receiver-side call as a separate entry" do
        expect(calls.map(&:method_name)).not_to include("new")
      end

      it "extracts calls from the receiver chain's arguments" do
        call = calls.find { |c| c.method_name == "build_order" }

        expect(call).not_to be_nil
        expect(call).to be_bare
      end
    end

    context "with instance variable receiver" do
      let(:source) do
        <<~RUBY
          class Foo
            def bar
              @order.destroy!
            end
          end
        RUBY
      end
      let(:calls) { described_class.extract(def_node_for(source, "bar")) }

      it "uses the ivar name as receiver" do
        call = calls.find { |c| c.method_name == "destroy!" }

        expect(call).not_to be_nil
        expect(call.receiver).to eq("@order")
      end
    end

    context "with local variable receiver" do
      let(:source) do
        <<~RUBY
          class Foo
            def bar(order)
              result = build_result
              result.success?
              order.save
            end
          end
        RUBY
      end
      let(:calls) { described_class.extract(def_node_for(source, "bar")) }

      it "uses the local variable name as receiver" do
        call = calls.find { |c| c.method_name == "success?" }

        expect(call).not_to be_nil
        expect(call.receiver).to eq("result")
        expect(call.label).to eq("result.success?")
      end

      it "uses the method parameter name as receiver" do
        call = calls.find { |c| c.method_name == "save" }

        expect(call).not_to be_nil
        expect(call.receiver).to eq("order")
      end
    end

    context "with a nested def inside a method body" do
      let(:source) do
        <<~RUBY
          class Foo
            def outer
              setup
              def inner
                secret_call
              end
            end
          end
        RUBY
      end
      let(:calls) { described_class.extract(def_node_for(source, "outer")) }

      it "extracts calls from the outer method but not from the nested def" do
        expect(calls.map(&:method_name)).to include("setup")
        expect(calls.map(&:method_name)).not_to include("secret_call")
      end
    end

    context "with absolute constant receiver (::Foo.bar)" do
      let(:source) do
        <<~RUBY
          class Foo
            def run
              ::TopLevel.execute
              Relative.execute
            end
          end
        RUBY
      end
      let(:calls) { described_class.extract(def_node_for(source, "run")) }

      it "marks ::TopLevel.execute as absolute" do
        call = calls.find { |c| c.receiver == "TopLevel" }

        expect(call).to be_absolute
      end

      it "does not mark Relative.execute as absolute" do
        call = calls.find { |c| c.receiver == "Relative" }

        expect(call).not_to be_absolute
      end
    end

    context "with ::Foo.new.execute chain" do
      let(:source) do
        <<~RUBY
          class Foo
            def run
              ::Service.new.execute
            end
          end
        RUBY
      end
      let(:calls) { described_class.extract(def_node_for(source, "run")) }

      it "propagates absolute through the call chain" do
        call = calls.find { |c| c.method_name == "execute" }

        expect(call).to be_absolute
      end
    end

    context "with an empty method body" do
      let(:source) do
        <<~RUBY
          class Foo
            def noop; end
          end
        RUBY
      end

      it "returns an empty array" do
        calls = described_class.extract(def_node_for(source, "noop"))
        expect(calls).to eq([])
      end
    end
  end
end
