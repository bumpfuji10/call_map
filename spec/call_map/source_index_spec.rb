# frozen_string_literal: true

require "spec_helper"

RSpec.describe CallMap::SourceIndex do
  subject(:index) { described_class.build(root: fixture_root) }

  let(:fixture_root) { File.expand_path("../fixtures/rails_app", __dir__) }

  describe "instance method の検索" do
    it "OrdersController#destroy を path / line 付きで検索できる" do
      definition = index.find_instance_method("OrdersController", "destroy")

      expect(definition).not_to be_nil
      expect(definition.kind).to eq(:instance_method)
      expect(definition.qualified_name).to eq("OrdersController#destroy")
      expect(definition.owner).to eq("OrdersController")
      expect(definition.path).to end_with("app/controllers/orders_controller.rb")
      expect(definition.line).to eq(7)
    end

    it "private method も同じく検索できる" do
      definition = index.find_instance_method("OrdersController", "set_order")

      expect(definition).not_to be_nil
      expect(definition.qualified_name).to eq("OrdersController#set_order")
    end

    it "存在しない method は nil を返す" do
      expect(index.find_instance_method("OrdersController", "unknown")).to be_nil
    end
  end

  describe "class method の検索" do
    it "OrderDeleteService.execute を検索できる" do
      definition = index.find_class_method("OrderDeleteService", "execute")

      expect(definition).not_to be_nil
      expect(definition.kind).to eq(:class_method)
      expect(definition.qualified_name).to eq("OrderDeleteService.execute")
      expect(definition.path).to end_with("app/services/order_delete_service.rb")
    end

    it "同名の instance method と class method を取り違えない" do
      class_method = index.find_class_method("OrderDeleteService", "execute")
      instance_method = index.find_instance_method("OrderDeleteService", "execute")

      expect(class_method.kind).to eq(:class_method)
      expect(instance_method.kind).to eq(:instance_method)
      expect(class_method.line).not_to eq(instance_method.line)
    end
  end

  describe "class / module 定義の検索" do
    it "class 定義を検索できる" do
      definition = index.find_class("OrderPolicy")

      expect(definition).not_to be_nil
      expect(definition.kind).to eq(:class)
      expect(definition.qualified_name).to eq("OrderPolicy")
    end

    it "ネストした namespace を修飾名で記録する" do
      definition = index.find_class("Admin::ReportsController")

      expect(definition).not_to be_nil
      expect(definition.kind).to eq(:class)

      action = index.find_instance_method("Admin::ReportsController", "index")
      expect(action).not_to be_nil
      expect(action.qualified_name).to eq("Admin::ReportsController#index")
    end
  end

  describe "metadata 枠" do
    it "後続 issue 用に metadata を空ハッシュで保持する" do
      definition = index.find_instance_method("OrdersController", "destroy")

      expect(definition.metadata).to eq({})
    end
  end
end
