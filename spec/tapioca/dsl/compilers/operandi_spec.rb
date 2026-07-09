# frozen_string_literal: true

require "spec_helper"

# Mock T module if sorbet-runtime is not available
# Must be defined before Tapioca mocks since Compiler extends T::Sig
unless defined?(T::Sig)
  module T
    def self.sig(&); end

    def self.type_member
      # Returns a placeholder for type_member
      nil
    end

    module Sig
      def sig(&); end
    end
  end
end

unless defined?(T::Enum)
  module T
    class Enum
      def initialize(serialized_value)
        @serialized_value = serialized_value
      end

      def serialize
        @serialized_value
      end

      def self.values
        []
      end
    end
  end
end

# Mock Tapioca modules for testing without tapioca dependency
module Tapioca
  module Dsl
    class Compiler
      extend T::Sig

      class << self
        extend T::Sig

        def type_member
          # Mock type_member for testing
          nil
        end

        def all_classes
          ObjectSpace.each_object(Class)
        end
      end

      attr_reader :constant, :root

      def initialize(constant, root)
        @constant = constant
        @root = root
      end

      def create_param(name, type:, default: nil)
        MockParam.new(name, type, default, :positional)
      end

      def create_opt_param(name, type:, default:)
        MockParam.new(name, type, default, :positional_opt)
      end

      def create_kw_param(name, type:)
        MockParam.new(name, type, nil, :keyword)
      end

      def create_kw_opt_param(name, type:, default:)
        MockParam.new(name, type, default, :keyword_opt)
      end
    end
  end
end

# Mock RBI module
module RBI
  class Scope
    attr_reader :methods, :classes, :nodes

    def initialize
      @methods = []
      @classes = []
      @nodes = []
    end

    def create_method(name, parameters: [], return_type: nil, visibility: nil, class_method: false)
      @methods << MockMethod.new(name, parameters, return_type, visibility, class_method)
    end

    def create_class(name, superclass_name: nil)
      child_scope = Scope.new
      yield child_scope if block_given?
      @classes << MockClass.new(name, superclass_name, child_scope)
      child_scope
    end

    def <<(node)
      @nodes << node
    end
  end

  class Tree
    def create_path(_constant)
      scope = Scope.new
      yield scope
      scope
    end
  end

  class Private
    def to_s
      "private"
    end
  end

  class TStructProp
    attr_reader :name, :type, :default

    def initialize(name, type, default: nil)
      @name = name
      @type = type
      @default = default
    end
  end
end

# Mock class for generated inner classes
class MockClass
  attr_reader :name, :superclass_name, :scope

  def initialize(name, superclass_name, scope)
    @name = name
    @superclass_name = superclass_name
    @scope = scope
  end
end

# Mock classes for testing
class MockParam
  attr_reader :name, :type, :default, :kind

  def initialize(name, type, default = nil, kind = :positional)
    @name = name
    @type = type
    @default = default
    @kind = kind
  end

  def keyword?
    @kind == :keyword || @kind == :keyword_opt
  end
end

class MockMethod
  attr_reader :name, :parameters, :return_type, :visibility, :class_method

  def initialize(name, parameters, return_type, visibility, class_method)
    @name = name
    @parameters = parameters
    @return_type = return_type
    @visibility = visibility
    @class_method = class_method
  end

  def private?
    visibility.is_a?(RBI::Private)
  end
end

class TapiocaCompilerStatus
  def initialize(serialized_value)
    @serialized_value = serialized_value
  end

  def serialize
    @serialized_value
  end

  Active = new("active")
  Archived = new("archived")
  VALUES = [Active, Archived].freeze

  def self.values
    VALUES
  end

  def self.try_deserialize(value)
    values.find { |enum_value| enum_value.serialize == value }
  end
end

require_relative "../../../../lib/tapioca/dsl/compilers/operandi"

RSpec.describe Tapioca::Dsl::Compilers::Operandi do
  let(:root) { RBI::Tree.new }
  let(:compiler) { described_class.new(service_class, root) }

  # Helper to find a method by name in the generated scope
  def find_method(scope, name)
    scope.methods.find { |m| m.name == name }
  end

  describe ".gather_constants" do
    it "returns all Operandi::Base descendants" do
      constants = described_class.gather_constants.to_a

      expect(constants).to include(CreateService)
      expect(constants).to include(User::Create)
    end

    it "excludes Operandi::Base itself" do
      constants = described_class.gather_constants.to_a

      expect(constants).not_to include(Operandi::Base)
    end

    it "excludes anonymous classes" do
      anonymous_service = Class.new(Operandi::Base) do
        arg :value, type: String
      end

      constants = described_class.gather_constants.to_a

      expect(constants).not_to include(anonymous_service)
    end
  end

  describe "#decorate" do
    context "with simple string argument" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "TestStringArgService"
          end

          arg :name, type: String
        end
      end

      it "generates getter method with correct return type" do
        scope = compiler.decorate

        getter = find_method(scope, "name")
        expect(getter).not_to be_nil
        expect(getter.return_type).to eq("::String")
      end

      it "generates predicate method with T::Boolean return type" do
        scope = compiler.decorate

        predicate = find_method(scope, "name?")
        expect(predicate).not_to be_nil
        expect(predicate.return_type).to eq("T::Boolean")
      end

      it "generates private setter method" do
        scope = compiler.decorate

        setter = find_method(scope, "name=")
        expect(setter).not_to be_nil
        expect(setter.private?).to be(true)
        expect(setter.return_type).to eq("::String")
        expect(setter.parameters.first.type).to eq("::String")
      end
    end

    context "with optional argument" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "TestOptionalArgService"
          end

          arg :email, type: String, optional: true
        end
      end

      it "generates getter with nilable return type" do
        scope = compiler.decorate

        getter = find_method(scope, "email")
        expect(getter.return_type).to eq("T.nilable(::String)")
      end

      it "generates setter with nilable parameter type" do
        scope = compiler.decorate

        setter = find_method(scope, "email=")
        expect(setter.parameters.first.type).to eq("T.nilable(::String)")
      end
    end

    context "with enum argument" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "TestEnumArgService"
          end

          arg :status, type: TapiocaCompilerStatus
        end
      end

      it "generates run parameter accepting enum values and raw serialized values" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        status_param = run_method.parameters.find { |p| p.name == "status" }

        expect(status_param.type).to eq("T.any(::TapiocaCompilerStatus, ::String)")
      end

      it "generates run! parameter accepting enum values and raw serialized values" do
        scope = compiler.decorate

        run_bang_method = find_method(scope, "run!")
        status_param = run_bang_method.parameters.find { |p| p.name == "status" }

        expect(status_param.type).to eq("T.any(::TapiocaCompilerStatus, ::String)")
      end

      it "keeps getter and setter typed as the enum class" do
        scope = compiler.decorate

        getter = find_method(scope, "status")
        setter = find_method(scope, "status=")

        expect(getter.return_type).to eq("::TapiocaCompilerStatus")
        expect(setter.return_type).to eq("::TapiocaCompilerStatus")
        expect(setter.parameters.first.type).to eq("::TapiocaCompilerStatus")
      end
    end

    context "with optional enum argument" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "TestOptionalEnumArgService"
          end

          arg :status, type: TapiocaCompilerStatus, optional: true
        end
      end

      it "generates nilable run parameter accepting enum values and raw serialized values" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        status_param = run_method.parameters.find { |p| p.name == "status" }

        expect(status_param.type).to eq("T.nilable(T.any(::TapiocaCompilerStatus, ::String))")
      end

      it "keeps getter and setter nilable over the enum class only" do
        scope = compiler.decorate

        getter = find_method(scope, "status")
        setter = find_method(scope, "status=")

        expect(getter.return_type).to eq("T.nilable(::TapiocaCompilerStatus)")
        expect(setter.parameters.first.type).to eq("T.nilable(::TapiocaCompilerStatus)")
      end
    end

    context "with multiple types (union)" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "TestUnionArgService"
          end

          arg :id, type: [String, Integer]
        end
      end

      it "generates getter with T.any union type" do
        scope = compiler.decorate

        getter = find_method(scope, "id")
        expect(getter.return_type).to eq("T.any(::String, ::Integer)")
      end
    end

    context "with boolean type (TrueClass, FalseClass)" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "TestBooleanArgService"
          end

          arg :active, type: [TrueClass, FalseClass]
        end
      end

      it "generates getter with T::Boolean type" do
        scope = compiler.decorate

        getter = find_method(scope, "active")
        expect(getter.return_type).to eq("T::Boolean")
      end
    end

    context "with output" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "TestOutputService"
          end

          output :result, type: Hash
        end
      end

      it "generates all three methods for output" do
        scope = compiler.decorate

        expect(find_method(scope, "result")).not_to be_nil
        expect(find_method(scope, "result?")).not_to be_nil
        expect(find_method(scope, "result=")).not_to be_nil
      end

      it "generates getter with correct return type" do
        scope = compiler.decorate

        getter = find_method(scope, "result")
        expect(getter.return_type).to eq("::Hash")
      end
    end

    context "with both arguments and outputs" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "TestMixedService"
          end

          arg :input, type: String
          output :result, type: Integer
        end
      end

      it "generates methods for both arguments and outputs" do
        scope = compiler.decorate

        expect(find_method(scope, "input")).not_to be_nil
        expect(find_method(scope, "result")).not_to be_nil
      end

      it "generates 11 methods total (3 per field + 3 class methods + 2 collection accessors)" do
        scope = compiler.decorate

        # 3 class methods (run, run!, with) +6 field methods (3 per field) +2 collection accessors (arguments, outputs)
        expect(scope.methods.size).to eq(11)
      end
    end

    context "with no arguments or outputs" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "TestEmptyService"
          end
        end
      end

      it "still generates class methods even without arguments or outputs" do
        scope = compiler.decorate

        expect(find_method(scope, "run")).not_to be_nil
        expect(find_method(scope, "run!")).not_to be_nil
        expect(find_method(scope, "with")).not_to be_nil
      end
    end

    context "with custom class type" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "TestCustomClassService"
          end

          arg :user, type: User
          output :order, type: Order
        end
      end

      it "generates getter with fully qualified class name" do
        scope = compiler.decorate

        user_getter = find_method(scope, "user")
        expect(user_getter.return_type).to eq("::User")

        order_getter = find_method(scope, "order")
        expect(order_getter.return_type).to eq("::Order")
      end
    end

    context "with inherited arguments" do
      let(:parent_service) do
        Class.new(Operandi::Base) do
          def self.name
            "ParentService"
          end

          arg :parent_arg, type: String
        end
      end

      let(:service_class) do
        parent = parent_service
        Class.new(parent) do
          def self.name
            "ChildService"
          end

          arg :child_arg, type: Integer
        end
      end

      it "generates methods for both parent and child arguments" do
        scope = compiler.decorate

        expect(find_method(scope, "parent_arg")).not_to be_nil
        expect(find_method(scope, "child_arg")).not_to be_nil
      end
    end
  end

  describe "#resolve_type" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        def self.name
          "ResolveTypeTestService"
        end

        arg :test, type: String
      end
    end

    context "when type is nil" do
      it "returns T.untyped" do
        field = Operandi::Settings::Field.new(:no_type, service_class, field_type: :argument)
        field.instance_variable_set(:@type, nil)

        result = compiler.send(:resolve_type, field)

        expect(result).to eq("T.untyped")
      end
    end

    context "when type is an unrecognized object" do
      it "returns T.untyped" do
        field = Operandi::Settings::Field.new(:unknown_type, service_class, field_type: :argument)
        field.instance_variable_set(:@type, "some random string")

        result = compiler.send(:resolve_type, field)

        expect(result).to eq("T.untyped")
      end
    end
  end

  describe "T.untyped scenarios" do
    context "when argument has no type option" do
      let(:service_class) do
        # Create a service with a field that has no type
        klass = Class.new(Operandi::Base) do
          def self.name
            "NoTypeService"
          end
        end

        # Manually create a field without type validation
        field = Operandi::Settings::Field.new(:untyped_arg, klass, field_type: :argument)
        field.instance_variable_set(:@type, nil)
        klass.own_arguments[:untyped_arg] = field
        klass.instance_variable_set(:@arguments, nil) # Clear memoized

        klass
      end

      it "generates getter with T.untyped return type" do
        scope = compiler.decorate

        getter = find_method(scope, "untyped_arg")
        expect(getter.return_type).to eq("T.untyped")
      end

      it "generates setter with T.untyped parameter type" do
        scope = compiler.decorate

        setter = find_method(scope, "untyped_arg=")
        expect(setter.parameters.first.type).to eq("T.untyped")
      end

      it "still generates predicate with T::Boolean" do
        scope = compiler.decorate

        predicate = find_method(scope, "untyped_arg?")
        expect(predicate.return_type).to eq("T::Boolean")
      end
    end

    context "when optional field has no type" do
      let(:service_class) do
        klass = Class.new(Operandi::Base) do
          def self.name
            "OptionalNoTypeService"
          end
        end

        # Manually create an optional field without type
        field = Operandi::Settings::Field.new(:optional_untyped, klass, field_type: :argument, optional: true)
        field.instance_variable_set(:@type, nil)
        klass.own_arguments[:optional_untyped] = field
        klass.instance_variable_set(:@arguments, nil)

        klass
      end

      it "generates getter with T.untyped (not nilable-wrapped)" do
        scope = compiler.decorate

        getter = find_method(scope, "optional_untyped")
        # T.untyped already includes nil, so no wrapping
        expect(getter.return_type).to eq("T.untyped")
      end
    end

    context "when type is an unrecognized object" do
      let(:service_class) do
        klass = Class.new(Operandi::Base) do
          def self.name
            "UnrecognizedTypeService"
          end
        end

        # Create a mock type that doesn't match Class/Module
        mock_type = Object.new
        mock_type.define_singleton_method(:to_s) { "CustomType::Unknown" }

        field = Operandi::Settings::Field.new(:unknown_type, klass, field_type: :argument)
        field.instance_variable_set(:@type, mock_type)
        klass.own_arguments[:unknown_type] = field
        klass.instance_variable_set(:@arguments, nil)

        klass
      end

      it "returns T.untyped when type is unrecognized" do
        scope = compiler.decorate

        getter = find_method(scope, "unknown_type")
        expect(getter.return_type).to eq("T.untyped")
      end
    end
  end

  describe "edge cases" do
    context "with module type instead of class" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "ModuleTypeService"
          end

          arg :enumerable_thing, type: Enumerable
        end
      end

      it "generates getter with module name" do
        scope = compiler.decorate

        getter = find_method(scope, "enumerable_thing")
        expect(getter.return_type).to eq("::Enumerable")
      end
    end

    context "with array containing single type" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "SingleTypeArrayService"
          end

          arg :value, type: [String]
        end
      end

      it "generates getter with single type (not T.any)" do
        scope = compiler.decorate

        getter = find_method(scope, "value")
        expect(getter.return_type).to eq("::String")
      end
    end

    context "with duplicate types in array" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "DuplicateTypeService"
          end

          arg :value, type: [String, String]
        end
      end

      it "deduplicates types" do
        scope = compiler.decorate

        getter = find_method(scope, "value")
        expect(getter.return_type).to eq("::String")
      end
    end

    context "with array containing multiple Ruby classes" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "ArrayWithMultipleClassesService"
          end

          arg :value, type: [String, Integer]
        end
      end

      it "resolves to T.any union" do
        scope = compiler.decorate

        getter = find_method(scope, "value")
        expect(getter.return_type).to eq("T.any(::String, ::Integer)")
      end
    end

    context "with array containing unrecognized type" do
      let(:service_class) do
        klass = Class.new(Operandi::Base) do
          def self.name
            "ArrayWithUnknownTypeService"
          end
        end

        # Manually create a field with an array containing an unrecognized type
        field = Operandi::Settings::Field.new(:mixed_unknown, klass, field_type: :argument)
        field.instance_variable_set(:@type, [String, "unknown_type", Integer])
        klass.own_arguments[:mixed_unknown] = field
        klass.instance_variable_set(:@arguments, nil)

        klass
      end

      it "includes T.untyped for unrecognized types in union" do
        scope = compiler.decorate

        getter = find_method(scope, "mixed_unknown")
        expect(getter.return_type).to eq("T.any(::String, T.untyped, ::Integer)")
      end
    end
  end

  describe "class methods generation" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        def self.name
          "ClassMethodsTestService"
        end

        arg :name, type: String
        arg :email, type: String, optional: true
        arg :admin, type: [TrueClass, FalseClass], default: false
      end
    end

    describe ".run class method" do
      it "generates .run as a class method" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        expect(run_method).not_to be_nil
        expect(run_method.class_method).to be(true)
      end

      it "has correct return type (T.attached_class)" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        expect(run_method.return_type).to eq("T.attached_class")
      end

      it "generates keyword parameters for each argument" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        expect(run_method.parameters.size).to eq(3)
        expect(run_method.parameters.all?(&:keyword?)).to be(true)
      end

      it "generates required keyword param for required argument" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        name_param = run_method.parameters.find { |p| p.name == "name" }

        expect(name_param).not_to be_nil
        expect(name_param.type).to eq("::String")
        expect(name_param.kind).to eq(:keyword)
        expect(name_param.default).to be_nil
      end

      it "generates optional keyword param with nil default for optional argument" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        email_param = run_method.parameters.find { |p| p.name == "email" }

        expect(email_param).not_to be_nil
        expect(email_param.type).to eq("T.nilable(::String)")
        expect(email_param.kind).to eq(:keyword_opt)
        expect(email_param.default).to eq("nil")
      end

      it "generates optional keyword param with default value" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        admin_param = run_method.parameters.find { |p| p.name == "admin" }

        expect(admin_param).not_to be_nil
        expect(admin_param.type).to eq("T::Boolean")
        expect(admin_param.kind).to eq(:keyword_opt)
        expect(admin_param.default).to eq("false")
      end
    end

    describe ".run! class method" do
      it "generates .run! as a class method" do
        scope = compiler.decorate

        run_bang_method = find_method(scope, "run!")
        expect(run_bang_method).not_to be_nil
        expect(run_bang_method.class_method).to be(true)
      end

      it "has correct return type (T.attached_class)" do
        scope = compiler.decorate

        run_bang_method = find_method(scope, "run!")
        expect(run_bang_method.return_type).to eq("T.attached_class")
      end

      it "generates same keyword parameters as .run" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        run_bang_method = find_method(scope, "run!")

        expect(run_bang_method.parameters.size).to eq(run_method.parameters.size)
        run_bang_method.parameters.each_with_index do |param, i|
          expect(param.name).to eq(run_method.parameters[i].name)
          expect(param.type).to eq(run_method.parameters[i].type)
          expect(param.kind).to eq(run_method.parameters[i].kind)
        end
      end
    end

    describe ".with class method" do
      it "generates .with as a class method" do
        scope = compiler.decorate

        with_method = find_method(scope, "with")
        expect(with_method).not_to be_nil
        expect(with_method.class_method).to be(true)
      end

      it "has correct return type (T.self_type)" do
        scope = compiler.decorate

        with_method = find_method(scope, "with")
        expect(with_method.return_type).to eq("T.self_type")
      end

      it "has two positional parameters: service_or_config (required) and config (optional)" do
        scope = compiler.decorate

        with_method = find_method(scope, "with")
        expect(with_method.parameters.size).to eq(2)

        service_or_config_param = with_method.parameters.first
        expect(service_or_config_param.name).to eq("service_or_config")
        expect(service_or_config_param.type)
          .to eq("T.any(::Operandi::Base, T::Hash[T.any(::String, ::Symbol), T.untyped])")
        expect(service_or_config_param.default).to be_nil
        expect(service_or_config_param.keyword?).to be(false)

        config_param = with_method.parameters.last
        expect(config_param.name).to eq("config")
        expect(config_param.type).to eq("T::Hash[T.any(::String, ::Symbol), T.untyped]")
        expect(config_param.default).to eq("{}")
        expect(config_param.keyword?).to be(false)
      end
    end

    context "with inheritance" do
      let(:parent_service) do
        Class.new(Operandi::Base) do
          def self.name
            "ParentServiceWithClassMethods"
          end

          arg :parent_arg, type: String
        end
      end

      let(:service_class) do
        parent = parent_service
        Class.new(parent) do
          def self.name
            "ChildServiceWithClassMethods"
          end

          arg :child_arg, type: Integer
        end
      end

      it "generates class methods for child service" do
        scope = compiler.decorate

        expect(find_method(scope, "run")).not_to be_nil
        expect(find_method(scope, "run!")).not_to be_nil
        expect(find_method(scope, "with")).not_to be_nil
      end

      it "child service .run returns T.attached_class (preserves concrete type)" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        expect(run_method.return_type).to eq("T.attached_class")
      end

      it "child service .run includes both parent and child arguments" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        param_names = run_method.parameters.map(&:name)

        expect(param_names).to include("parent_arg")
        expect(param_names).to include("child_arg")
      end
    end

    context "with no arguments" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "NoArgsService"
          end
        end
      end

      it "generates .run with no parameters" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        expect(run_method.parameters).to be_empty
      end

      it "generates .run! with no parameters" do
        scope = compiler.decorate

        run_bang_method = find_method(scope, "run!")
        expect(run_bang_method.parameters).to be_empty
      end
    end

    context "with optional argument before required (Sorbet parameter ordering)" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "MixedOrderService"
          end

          # Optional defined before required
          arg :name, type: String, optional: true
          arg :provider, type: String
          arg :count, type: Integer, default: 1
        end
      end

      it "sorts required parameters before optional ones" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        param_kinds = run_method.parameters.map(&:kind)

        # Required params (:keyword) should come before optional (:keyword_opt)
        required_indices = param_kinds.each_index.select { |i| param_kinds[i] == :keyword }
        optional_indices = param_kinds.each_index.select { |i| param_kinds[i] == :keyword_opt }

        expect(required_indices.max || -1).to be < (optional_indices.min || Float::INFINITY)
      end

      it "places provider (required) before name and count (optional)" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        param_names = run_method.parameters.map(&:name)

        provider_index = param_names.index("provider")
        name_index = param_names.index("name")
        count_index = param_names.index("count")

        expect(provider_index).to be < name_index
        expect(provider_index).to be < count_index
      end
    end

    context "with various default value types" do
      let(:service_class) do
        Class.new(Operandi::Base) do
          def self.name
            "DefaultValuesService"
          end

          arg :string_default, type: String, default: "hello"
          arg :symbol_default, type: Symbol, default: :world
          arg :numeric_default, type: Integer, default: 42
          arg :nil_default, type: String, optional: true, default: nil
          arg :empty_hash_default, type: Hash, default: {}
          arg :empty_array_default, type: Array, default: []
          arg :proc_default, type: String, default: -> { "computed" }
        end
      end

      it "formats string defaults correctly" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        param = run_method.parameters.find { |p| p.name == "string_default" }
        expect(param.default).to eq('"hello"')
      end

      it "formats symbol defaults correctly" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        param = run_method.parameters.find { |p| p.name == "symbol_default" }
        expect(param.default).to eq(":world")
      end

      it "formats numeric defaults correctly" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        param = run_method.parameters.find { |p| p.name == "numeric_default" }
        expect(param.default).to eq("42")
      end

      it "formats nil defaults correctly" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        param = run_method.parameters.find { |p| p.name == "nil_default" }
        expect(param.default).to eq("nil")
      end

      it "formats empty hash defaults correctly" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        param = run_method.parameters.find { |p| p.name == "empty_hash_default" }
        expect(param.default).to eq("{}")
      end

      it "formats empty array defaults correctly" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        param = run_method.parameters.find { |p| p.name == "empty_array_default" }
        expect(param.default).to eq("[]")
      end

      it "formats Proc defaults as T.unsafe(nil)" do
        scope = compiler.decorate

        run_method = find_method(scope, "run")
        param = run_method.parameters.find { |p| p.name == "proc_default" }
        expect(param.default).to eq("T.unsafe(nil)")
      end
    end
  end
end
