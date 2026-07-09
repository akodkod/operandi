# frozen_string_literal: true

return unless defined?(Tapioca::Dsl::Compiler)

module Tapioca
  module Dsl
    module Compilers
      # Tapioca DSL compiler for Operandi
      #
      # Generates RBI signatures for methods automatically defined by the
      # `arg`/`argument` and `output` DSL macros in operandi.
      #
      # For each argument and output, three methods are generated:
      # - Getter: `def name` - returns the value
      # - Predicate: `def name?` - returns boolean
      # - Setter: `def name=` (private) - sets the value
      #
      # Additionally, typed inner classes are generated:
      # - `Arguments` - T::Struct representing all service arguments
      # - `Outputs` - T::Struct representing all service outputs
      #
      # @example Service definition
      #   class CreateUser < Operandi::Base
      #     arg :name, type: String
      #     arg :email, type: String, optional: true
      #     arg :role, type: [Symbol, String]
      #
      #     output :user, type: User
      #   end
      #
      # @example Generated RBI
      #   class CreateUser
      #     class Arguments < T::Struct
      #       prop :name, ::String
      #       prop :email, T.nilable(::String), default: nil
      #       prop :role, T.any(::Symbol, ::String)
      #     end
      #
      #     class Outputs < T::Struct
      #       prop :user, ::User
      #     end
      #
      #     sig { returns(Arguments) }
      #     def arguments; end
      #
      #     sig { returns(Outputs) }
      #     def outputs; end
      #
      #     sig { returns(String) }
      #     def name; end
      #
      #     sig { returns(T::Boolean) }
      #     def name?; end
      #
      #     sig { returns(T.nilable(String)) }
      #     def email; end
      #
      #     sig { returns(T::Boolean) }
      #     def email?; end
      #
      #     sig { returns(T.any(Symbol, String)) }
      #     def role; end
      #
      #     sig { returns(T::Boolean) }
      #     def role?; end
      #
      #     sig { returns(User) }
      #     def user; end
      #
      #     sig { returns(T::Boolean) }
      #     def user?; end
      #
      #     private
      #
      #     sig { params(value: String).returns(String) }
      #     def name=(value); end
      #
      #     # ... other setters
      #   end
      class Operandi < Compiler # rubocop:disable Metrics/ClassLength
        extend T::Sig

        ConstantType = type_member { { fixed: T.class_of(::Operandi::Base) } }
        CONFIG_TYPE = "T::Hash[T.any(::String, ::Symbol), T.untyped]"
        SERVICE_OR_CONFIG_TYPE = "T.any(::Operandi::Base, #{CONFIG_TYPE})".freeze

        class << self
          extend T::Sig

          sig { override.returns(T::Enumerable[Module]) }
          def gather_constants
            all_classes.select do |klass|
              klass < ::Operandi::Base && klass.name && klass != ::Operandi::Base
            end
          end
        end

        sig { override.void }
        def decorate
          root.create_path(constant) do |klass|
            # Generate class methods (.run, .run!, .with)
            generate_class_methods(klass)

            # Generate typed inner classes for arguments and outputs
            generate_arguments_type(klass)
            generate_outputs_type(klass)

            # Generate argument methods
            constant.arguments.each_value do |field|
              generate_field_methods(klass, field)
            end

            # Generate output methods
            constant.outputs.each_value do |field|
              generate_field_methods(klass, field)
            end
          end
        end

        private

        sig { params(klass: RBI::Scope).void }
        def generate_class_methods(klass)
          generate_run_method(klass)
          generate_run_bang_method(klass)
          generate_with_method(klass)
        end

        sig { params(klass: RBI::Scope).void }
        def generate_arguments_type(klass)
          return if constant.arguments.empty?

          generate_struct_class(klass, "Arguments", constant.arguments)
          klass.create_method("arg", return_type: "Arguments")
        end

        sig { params(klass: RBI::Scope).void }
        def generate_outputs_type(klass)
          return if constant.outputs.empty?

          generate_struct_class(klass, "Outputs", constant.outputs)
          klass.create_method("output", return_type: "Outputs")
        end

        sig { params(klass: RBI::Scope).void }
        def generate_run_method(klass)
          klass.create_method(
            "run",
            parameters: generate_argument_parameters,
            return_type: "T.attached_class",
            class_method: true,
          )
        end

        sig { params(klass: RBI::Scope).void }
        def generate_run_bang_method(klass)
          klass.create_method(
            "run!",
            parameters: generate_argument_parameters,
            return_type: "T.attached_class",
            class_method: true,
          )
        end

        sig { params(klass: RBI::Scope).void }
        def generate_with_method(klass)
          klass.create_method(
            "with",
            parameters: [create_param("service_or_config", type: SERVICE_OR_CONFIG_TYPE),
                         create_opt_param("config", type: CONFIG_TYPE, default: "{}"),],
            return_type: "T.self_type",
            class_method: true,
          )
        end

        sig { returns(T::Array[T.untyped]) }
        def generate_argument_parameters
          # Sort required params before optional (Sorbet requirement)
          constant.arguments
            .sort_by { |_, field| field.optional || field.default_exists ? 1 : 0 }
            .map { |name, field| create_argument_param(name, field) }
        end

        sig { params(name: Symbol, field: ::Operandi::Settings::Field).returns(T.untyped) }
        def create_argument_param(name, field)
          ruby_type = resolve_argument_input_type(field)
          return create_kw_param(name.to_s, type: ruby_type) unless field.optional || field.default_exists

          param_type = field.optional ? as_nilable_type(ruby_type) : ruby_type
          create_kw_opt_param(name.to_s, type: param_type, default: format_default_value(field))
        end

        sig { params(field: ::Operandi::Settings::Field).returns(String) }
        def format_default_value(field)
          return "nil" if field.optional && !field.default_exists
          return "T.unsafe(nil)" unless field.default_exists

          format_literal_default(field.default)
        end

        sig { params(default: T.untyped).returns(String) }
        def format_literal_default(default)
          case default
          when String, Symbol then default.inspect
          when Numeric, TrueClass, FalseClass then default.to_s
          when NilClass then "nil"
          when Hash then default.empty? ? "{}" : "T.unsafe(nil)"
          when Array then default.empty? ? "[]" : "T.unsafe(nil)"
          else "T.unsafe(nil)" # Proc and other complex types
          end
        end

        sig { params(field: ::Operandi::Settings::Field).returns(String) }
        def resolve_argument_input_type(field)
          type = field.instance_variable_get(:@type)
          return resolve_enum_argument_input_type(type) if sorbet_enum_class?(type)

          resolve_type(field)
        end

        sig { params(type: T.class_of(T::Enum)).returns(String) }
        def resolve_enum_argument_input_type(type)
          any_type_for([ruby_type_for_class(type), *enum_serialized_types(type)])
        end

        sig { params(type: T.class_of(T::Enum)).returns(T::Array[String]) }
        def enum_serialized_types(type)
          type.values.map { |value| ruby_type_for_class(value.serialize.class) }.uniq
        rescue StandardError
          []
        end

        sig { params(types: T::Array[String]).returns(String) }
        def any_type_for(types)
          resolved_types = types.uniq
          return resolved_types.first if resolved_types.size == 1

          "T.any(#{resolved_types.join(', ')})"
        end

        sig { params(klass: RBI::Scope, field: ::Operandi::Settings::Field).void }
        def generate_field_methods(klass, field)
          name = field.name.to_s
          ruby_type = resolve_type(field)
          return_type = field.optional ? as_nilable_type(ruby_type) : ruby_type

          # Getter
          klass.create_method(name, return_type: return_type)

          # Predicate
          klass.create_method("#{name}?", return_type: "T::Boolean")

          # Setter (private)
          klass.create_method(
            "#{name}=",
            parameters: [create_param("value", type: return_type)],
            return_type: return_type,
            visibility: RBI::Private.new,
          )
        end

        sig { params(field: ::Operandi::Settings::Field).returns(String) }
        def resolve_type(field)
          type = field.instance_variable_get(:@type)
          return "T.untyped" unless type

          if type.is_a?(Array)
            resolve_array_type(type)
          elsif sorbet_type?(type)
            resolve_sorbet_type(type)
          elsif type.is_a?(Class) || type.is_a?(Module)
            ruby_type_for_class(type)
          else
            "T.untyped"
          end
        end

        sig { params(types: T::Array[T.untyped]).returns(String) }
        def resolve_array_type(types)
          resolved_types = types.map do |t|
            if t.is_a?(Class) || t.is_a?(Module)
              ruby_type_for_class(t)
            else
              "T.untyped"
            end
          end.uniq

          return resolved_types.first if resolved_types.size == 1

          # Check if this is a boolean type (TrueClass + FalseClass)
          if resolved_types.sort == ["::FalseClass", "::TrueClass"]
            "T::Boolean"
          else
            "T.any(#{resolved_types.join(', ')})"
          end
        end

        sig { params(klass: T.any(Class, Module)).returns(String) }
        def ruby_type_for_class(klass)
          name = klass.name
          return "T.untyped" unless name

          # Handle boolean types specially
          if klass == TrueClass
            "::TrueClass"
          elsif klass == FalseClass
            "::FalseClass"
          else
            "::#{name}"
          end
        end

        sig { params(type: T.untyped).returns(T::Boolean) }
        def sorbet_type?(type)
          defined?(T::Types::Base) && type.is_a?(T::Types::Base)
        end

        sig { params(type: T.untyped).returns(T::Boolean) }
        def sorbet_enum_class?(type)
          return false unless type.is_a?(Class)

          (defined?(T::Enum) && type < T::Enum) || serializable_enum_class?(type)
        end

        sig { params(type: Class).returns(T::Boolean) }
        def serializable_enum_class?(type)
          type.respond_to?(:try_deserialize) &&
            type.respond_to?(:values) &&
            type.values.any? &&
            type.values.all? { |value| value.respond_to?(:serialize) }
        rescue StandardError
          false
        end

        sig { params(type: T.untyped).returns(String) }
        def resolve_sorbet_type(type)
          type.name || "T.untyped"
        end

        sig { params(type: String).returns(String) }
        def as_nilable_type(type)
          # Don't double-wrap nilable types
          return type if type.start_with?("T.nilable(")
          return type if type == "T.untyped"

          "T.nilable(#{type})"
        end

        sig do
          params(
            klass: RBI::Scope,
            class_name: String,
            fields: T::Hash[Symbol, ::Operandi::Settings::Field],
          ).void
        end
        def generate_struct_class(klass, class_name, fields)
          return if fields.empty?

          klass.create_class(class_name, superclass_name: "T::Struct") do |struct_klass|
            fields.each_value do |field|
              generate_struct_prop(struct_klass, field)
            end
          end
        end

        sig { params(struct_klass: RBI::Scope, field: ::Operandi::Settings::Field).void }
        def generate_struct_prop(struct_klass, field)
          name = field.name.to_s
          ruby_type = resolve_type(field)
          prop_type = field.optional ? as_nilable_type(ruby_type) : ruby_type
          default_value = format_default_value(field) if field.optional || field.default_exists

          struct_klass << RBI::TStructProp.new(name, prop_type, default: default_value)
        end
      end
    end
  end
end
