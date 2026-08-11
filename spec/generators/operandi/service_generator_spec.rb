# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "erb"

# Helper class to provide binding context for ERB template rendering
class GeneratorTemplateContext
  def initialize(locals)
    locals.each do |key, value|
      instance_variable_set("@#{key}", value)
      define_singleton_method(key) { instance_variable_get("@#{key}") }
    end
  end

  def template_binding
    binding
  end
end

RSpec.describe "Operandi::Generators::ServiceGenerator" do
  let(:destination_root) { Dir.mktmpdir }
  let(:templates_path) do
    File.expand_path("../../../lib/generators/operandi/service/templates", __dir__)
  end

  before do
    FileUtils.mkdir_p(destination_root)
  end

  after do
    FileUtils.rm_rf(destination_root)
  end

  # Helper to render ERB templates with local variables
  def render_template(template_name, locals = {})
    template_path = File.join(templates_path, template_name)
    template_content = File.read(template_path)

    # Create a binding with the local variables
    binding_context = GeneratorTemplateContext.new(locals)
    ERB.new(template_content, trim_mode: "-").result(binding_context.template_binding)
  end

  describe "service.rb template" do
    it "exists" do
      template_path = File.join(templates_path, "service.rb.tt")
      expect(File.exist?(template_path)).to be true
    end

    it "generates a simple service" do
      content = render_template(
        "service.rb.tt",
        class_name: "CreateUser",
        parent_class: "ApplicationService",
        arguments: [],
        steps: [],
        outputs: [],
      )

      expect(content).to include("frozen_string_literal: true")
      expect(content).to include("class CreateUser < ApplicationService")
    end

    it "generates a namespaced service" do
      content = render_template(
        "service.rb.tt",
        class_name: "User::Create",
        parent_class: "ApplicationService",
        arguments: [],
        steps: [],
        outputs: [],
      )

      expect(content).to include("class User::Create < ApplicationService")
    end

    it "generates service with custom parent class" do
      content = render_template(
        "service.rb.tt",
        class_name: "MyService",
        parent_class: "BaseService",
        arguments: [],
        steps: [],
        outputs: [],
      )

      expect(content).to include("class MyService < BaseService")
    end

    it "generates service with arguments" do
      content = render_template(
        "service.rb.tt",
        class_name: "CreateUser",
        parent_class: "ApplicationService",
        arguments: ["name", "email", "role"],
        steps: [],
        outputs: [],
      )

      expect(content).to include("# Arguments")
      expect(content).to include("arg :name")
      expect(content).to include("arg :email")
      expect(content).to include("arg :role")
    end

    it "generates service with steps" do
      content = render_template(
        "service.rb.tt",
        class_name: "CreateUser",
        parent_class: "ApplicationService",
        arguments: [],
        steps: ["validate", "create", "notify"],
        outputs: [],
      )

      expect(content).to include("# Steps")
      expect(content).to include("step :validate")
      expect(content).to include("step :create")
      expect(content).to include("step :notify")
    end

    it "generates private methods for steps" do
      content = render_template(
        "service.rb.tt",
        class_name: "CreateUser",
        parent_class: "ApplicationService",
        arguments: [],
        steps: ["validate", "create"],
        outputs: [],
      )

      expect(content).to include("private")
      expect(content).to include("def validate")
      expect(content).to include("# TODO: Implement validate")
      expect(content).to include("def create")
      expect(content).to include("# TODO: Implement create")
    end

    it "generates service with outputs" do
      content = render_template(
        "service.rb.tt",
        class_name: "CreateUser",
        parent_class: "ApplicationService",
        arguments: [],
        steps: [],
        outputs: ["user", "message"],
      )

      expect(content).to include("# Outputs")
      expect(content).to include("output :user")
      expect(content).to include("output :message")
    end

    it "generates complete service with all options" do
      content = render_template(
        "service.rb.tt",
        class_name: "User::Create",
        parent_class: "ApplicationService",
        arguments: ["name", "email"],
        steps: ["validate", "persist"],
        outputs: ["user"],
      )

      expect(content).to include("class User::Create < ApplicationService")
      expect(content).to include("arg :name")
      expect(content).to include("arg :email")
      expect(content).to include("step :validate")
      expect(content).to include("step :persist")
      expect(content).to include("output :user")
      expect(content).to include("def validate")
      expect(content).to include("def persist")
    end
  end

  describe "service_spec.rb template" do
    it "exists" do
      template_path = File.join(templates_path, "service_spec.rb.tt")
      expect(File.exist?(template_path)).to be true
    end

    it "generates a simple spec" do
      content = render_template(
        "service_spec.rb.tt",
        class_name: "CreateUser",
        arguments: [],
        steps: [],
        outputs: [],
      )

      expect(content).to include("frozen_string_literal: true")
      expect(content).to include('require "rails_helper"')
      expect(content).to include("RSpec.describe CreateUser, type: :service")
    end

    it "generates spec with argument matchers" do
      content = render_template(
        "service_spec.rb.tt",
        class_name: "CreateUser",
        arguments: ["name", "email"],
        steps: [],
        outputs: [],
      )

      expect(content).to include('describe "arguments"')
      expect(content).to include("it { is_expected.to define_argument(:name) }")
      expect(content).to include("it { is_expected.to define_argument(:email) }")
    end

    it "generates spec with step matchers" do
      content = render_template(
        "service_spec.rb.tt",
        class_name: "CreateUser",
        arguments: [],
        steps: ["validate", "create"],
        outputs: [],
      )

      expect(content).to include('describe "steps"')
      expect(content).to include("it { is_expected.to define_step(:validate) }")
      expect(content).to include("it { is_expected.to define_step(:create) }")
    end

    it "generates spec with output matchers" do
      content = render_template(
        "service_spec.rb.tt",
        class_name: "CreateUser",
        arguments: [],
        steps: [],
        outputs: ["user", "message"],
      )

      expect(content).to include('describe "outputs"')
      expect(content).to include("it { is_expected.to define_output(:user) }")
      expect(content).to include("it { is_expected.to define_output(:message) }")
    end

    it "generates spec with #run describe block" do
      content = render_template(
        "service_spec.rb.tt",
        class_name: "CreateUser",
        arguments: [],
        steps: [],
        outputs: [],
      )

      expect(content).to include('describe "#run"')
      expect(content).to include("subject(:service) { described_class.run(**args) }")
    end

    it "generates namespaced spec" do
      content = render_template(
        "service_spec.rb.tt",
        class_name: "User::Create",
        arguments: [],
        steps: [],
        outputs: [],
      )

      expect(content).to include("RSpec.describe User::Create, type: :service")
    end
  end
end
