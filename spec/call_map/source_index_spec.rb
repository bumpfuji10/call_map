# frozen_string_literal: true

require "spec_helper"

RSpec.describe CallMap::SourceIndex do
  # Root of the fixture app. __dir__ is spec/call_map, so resolve
  # spec/fixtures/rails_app into an absolute path from there.
  let(:fixture_root) { File.expand_path("../fixtures/rails_app", __dir__) }

  # The index used in each example: a SourceIndex built from the fixture app.
  subject(:index) { described_class.build(root: fixture_root) }

  describe "#find_instance_method" do
    it "finds an instance method with its path and line" do
      definition = index.find_instance_method("OrdersController", "destroy")

      expect(definition).not_to be_nil
      expect(definition.kind).to eq(:instance_method)
      expect(definition.qualified_name).to eq("OrdersController#destroy")
      expect(definition.owner).to eq("OrdersController")
      expect(definition.path).to end_with("app/controllers/orders_controller.rb")
      expect(definition.line).to eq(4)
    end

    it "finds a private method as well" do
      definition = index.find_instance_method("OrdersController", "set_order")

      expect(definition).not_to be_nil
      expect(definition.qualified_name).to eq("OrdersController#set_order")
    end

    it "returns nil for an unknown method" do
      expect(index.find_instance_method("OrdersController", "unknown")).to be_nil
    end
  end

  describe "#find_class_method" do
    it "finds a class method" do
      definition = index.find_class_method("OrderDeleteService", "execute")

      expect(definition).not_to be_nil
      expect(definition.kind).to eq(:class_method)
      expect(definition.qualified_name).to eq("OrderDeleteService.execute")
    end

    it "does not confuse a class method with a same-named instance method" do
      class_method = index.find_class_method("OrderDeleteService", "execute")
      instance_method = index.find_instance_method("OrderDeleteService", "execute")

      expect(class_method.kind).to eq(:class_method)
      expect(instance_method.kind).to eq(:instance_method)
      expect(class_method.line).not_to eq(instance_method.line)
    end

    it "finds a class method defined with an explicit constant receiver" do
      definition = index.find_class_method("LegacyReportService", "generate")

      expect(definition).not_to be_nil
      expect(definition.kind).to eq(:class_method)
      expect(definition.qualified_name).to eq("LegacyReportService.generate")
    end

    it "finds a class method defined inside `class << self`" do
      definition = index.find_class_method("OrderArchiveService", "execute")

      expect(definition).not_to be_nil
      expect(definition.kind).to eq(:class_method)
      expect(definition.qualified_name).to eq("OrderArchiveService.execute")
    end

    it "still treats a regular instance method as instance method (not singleton)" do
      definition = index.find_instance_method("OrderArchiveService", "archive")

      expect(definition).not_to be_nil
      expect(definition.kind).to eq(:instance_method)
    end

    it "qualifies a constant-receiver class method with the enclosing namespace" do
      definition = index.find_class_method("Reports::Generator", "reset")

      expect(definition).not_to be_nil
      expect(definition.qualified_name).to eq("Reports::Generator.reset")
    end

    it "finds a class method defined inside `class << Constant` within a namespace" do
      definition = index.find_class_method("Reports::Generator", "build")

      expect(definition).not_to be_nil
      expect(definition.qualified_name).to eq("Reports::Generator.build")
    end

    it "does not register methods from an unresolvable `class << obj` as instance methods" do
      expect(index.find_instance_method("WidgetBuilder", "helper")).to be_nil
    end

    it "does not register methods with a non-constant receiver (`def obj.foo`)" do
      expect(index.find_class_method("WidgetBuilder", "configure")).to be_nil
      expect(index.find_instance_method("WidgetBuilder", "configure")).to be_nil
    end

    it "does not double-prefix an absolute constant receiver (`class << ::Foo::Bar`)" do
      definition = index.find_class_method("Reports::Generator", "export")

      expect(definition).not_to be_nil
      expect(definition.qualified_name).to eq("Reports::Generator.export")
    end
  end

  describe "nested namespace" do
    it "finds a method under a nested module/class with its qualified name" do
      definition = index.find_instance_method("Admin::ReportsController", "index")

      expect(definition).not_to be_nil
      expect(definition.qualified_name).to eq("Admin::ReportsController#index")
    end

    it "does not nest an absolute class definition under the enclosing namespace" do
      definition = index.find_instance_method("TopLevelService", "run")

      expect(definition).not_to be_nil
      expect(definition.qualified_name).to eq("TopLevelService#run")
      expect(definition.owner).to eq("TopLevelService")
    end
  end
end
