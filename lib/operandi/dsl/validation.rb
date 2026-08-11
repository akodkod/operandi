# frozen_string_literal: true

require_relative "../constants"

module Operandi
  module Dsl
    # Validates options accepted by argument, output, and step declarations
    module OptionsValidation
      VALID_OPTIONS = {
        argument: [:type, :optional, :default, :context].freeze,
        output: [:type, :optional, :default].freeze,
        step: [:if, :unless, :always, :before, :after, :parent].freeze,
      }.freeze

      # Validate that only supported DSL options are provided
      #
      # @param name [Symbol] the argument, output, or step name
      # @param field_type [Symbol] the DSL type (:argument, :output, or :step)
      # @param service_class [Class] the service class for error messages
      # @param opts [Hash] the options hash to validate
      def self.validate!(name, field_type, service_class, opts)
        valid_options = VALID_OPTIONS.fetch(field_type)
        unknown_options = opts.keys - valid_options
        return if unknown_options.empty?

        option_label = unknown_options.one? ? "option" : "options"
        formatted_unknown = unknown_options.map { |option| "`#{option}`" }.join(", ")
        formatted_valid = valid_options.map { |option| "`#{option}`" }.join(", ")

        raise Operandi::Error,
              "Unknown #{option_label} #{formatted_unknown} for #{field_type} `#{name}` in #{service_class}. " \
              "Valid options: #{formatted_valid}"
      end
    end

    # Shared validation logic for DSL modules
    module Validation
      # Validate that the name is a symbol
      #
      # @param name [Object] the name to validate
      # @param field_type [Symbol] the type of field (:argument, :output, :step)
      # @param service_class [Class] the service class for error messages
      def self.validate_symbol_name!(name, field_type, service_class)
        return if name.is_a?(Symbol)

        raise Operandi::InvalidNameError,
              "#{field_type.to_s.capitalize} name must be a Symbol, " \
              "got #{name.class} (#{name.inspect}) in #{service_class}"
      end

      # Validate that the name is not a reserved word
      #
      # @param name [Symbol] the name to validate
      # @param field_type [Symbol] the type of field (:argument, :output, :step)
      # @param service_class [Class] the service class for error messages
      def self.validate_reserved_name!(name, field_type, service_class)
        return unless ReservedNames::ALL.include?(name.to_sym)

        raise Operandi::ReservedNameError,
              "Cannot use `#{name}` as #{field_type} name in #{service_class} - " \
              "it is a reserved word that conflicts with gem methods"
      end

      # Validate that the name doesn't conflict with other defined names
      #
      # @param name [Symbol] the name to validate
      # @param field_type [Symbol] the type of field being defined (:argument, :output, :step)
      # @param service_class [Class] the service class to check for conflicts
      def self.validate_name_conflicts!(name, field_type, service_class)
        name_sym = name.to_sym

        case field_type
        when :argument
          validate_argument_conflicts!(name_sym, service_class)
        when :output
          validate_output_conflicts!(name_sym, service_class)
        when :step
          validate_step_conflicts!(name_sym, service_class)
        end
      end

      # Validate argument name doesn't conflict with outputs or steps
      def self.validate_argument_conflicts!(name_sym, service_class)
        # Check against existing outputs
        if has_output?(name_sym, service_class)
          raise Operandi::ReservedNameError,
                "Cannot use `#{name_sym}` as argument name in #{service_class} - " \
                "it is already defined as an output"
        end

        # Check against existing steps
        if has_step?(name_sym, service_class)
          raise Operandi::ReservedNameError,
                "Cannot use `#{name_sym}` as argument name in #{service_class} - " \
                "it is already defined as a step"
        end
      end

      # Validate output name doesn't conflict with arguments or steps
      def self.validate_output_conflicts!(name_sym, service_class)
        # Check against existing arguments
        if has_argument?(name_sym, service_class)
          raise Operandi::ReservedNameError,
                "Cannot use `#{name_sym}` as output name in #{service_class} - " \
                "it is already defined as an argument"
        end

        # Check against existing steps
        if has_step?(name_sym, service_class)
          raise Operandi::ReservedNameError,
                "Cannot use `#{name_sym}` as output name in #{service_class} - " \
                "it is already defined as a step"
        end
      end

      # Validate step name doesn't conflict with arguments or outputs
      def self.validate_step_conflicts!(name_sym, service_class)
        # Check against existing arguments
        if has_argument?(name_sym, service_class)
          raise Operandi::ReservedNameError,
                "Cannot use `#{name_sym}` as step name in #{service_class} - " \
                "it is already defined as an argument"
        end

        # Check against existing outputs
        if has_output?(name_sym, service_class)
          raise Operandi::ReservedNameError,
                "Cannot use `#{name_sym}` as step name in #{service_class} - " \
                "it is already defined as an output"
        end
      end

      # Check if a name is already defined as an argument
      def self.has_argument?(name_sym, service_class)
        # Check own_arguments (current class)
        (service_class.respond_to?(:own_arguments) && service_class.own_arguments.key?(name_sym)) ||
          # Check inherited arguments
          (service_class.superclass.respond_to?(:arguments) && service_class.superclass.arguments.key?(name_sym))
      end

      # Check if a name is already defined as an output
      def self.has_output?(name_sym, service_class)
        # Check own_outputs (current class)
        (service_class.respond_to?(:own_outputs) && service_class.own_outputs.key?(name_sym)) ||
          # Check inherited outputs
          (service_class.superclass.respond_to?(:outputs) && service_class.superclass.outputs.key?(name_sym))
      end

      # Check if a name is already defined as a step
      def self.has_step?(name_sym, service_class)
        # Check step_operations (current class) for non-removed steps
        (service_class.respond_to?(:step_operations) &&
         service_class.step_operations.any? { |op| op[:name] == name_sym && op[:action] != :remove }) ||
          # Check inherited steps
          (service_class.superclass.respond_to?(:steps) && service_class.superclass.steps.key?(name_sym))
      end

      # Validate that the type option is provided when require_type is enabled
      #
      # @param name [Symbol] the field name
      # @param field_type [Symbol] the type of field (:argument, :output)
      # @param service_class [Class] the service class for error messages
      # @param opts [Hash] the options hash to check for type
      def self.validate_type_required!(name, field_type, service_class, opts)
        return if opts.key?(:type)
        return unless require_type_enabled_for?(field_type, service_class)

        config_name = field_type == :argument ? "require_arg_type" : "require_output_type"
        raise Operandi::MissingTypeError,
              "#{field_type.to_s.capitalize} `#{name}` in #{service_class} must have a type specified " \
              "(#{config_name} is enabled)"
      end

      # Check if require_type is enabled for the given field type and service class
      #
      # @param field_type [Symbol] the type of field (:argument, :output)
      # @param service_class [Class] the service class to check
      # @return [Boolean] whether type is required for the field type
      def self.require_type_enabled_for?(field_type, service_class)
        config_key = field_type == :argument ? :require_arg_type : :require_output_type

        # Check class-level config in the inheritance chain, then fall back to global config
        klass = service_class
        while klass.respond_to?(:class_config)
          class_config = klass.class_config

          # Check specific config first (require_arg_type or require_output_type)
          return class_config[config_key] if class_config&.key?(config_key)

          # Check convenience config (require_type) for backward compatibility
          return class_config[:require_type] if class_config&.key?(:require_type)

          klass = klass.superclass
        end

        Operandi.config.public_send(config_key)
      end
    end
  end
end
