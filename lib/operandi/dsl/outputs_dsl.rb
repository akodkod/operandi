# frozen_string_literal: true

require_relative "../constants"
require_relative "validation"

module Operandi
  module Dsl
    # DSL for defining and managing service outputs
    module OutputsDsl
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Define an output for the service
        #
        # @param name [Symbol] the output name
        # @param opts [Hash] options for configuring the output
        # @option opts [Class, Array<Class>] :type Type(s) to validate against
        #   (e.g., Hash, String, [String, Symbol])
        # @option opts [Boolean] :optional (false) Whether nil values are allowed
        # @option opts [Object, Proc] :default Default value or proc to evaluate in instance context
        #
        # @example Define a required hash output
        #   output :result, type: Hash
        #
        # @example Define an optional output with default
        #   output :status, type: String, optional: true, default: "pending"
        #
        # @example Define an output with multiple allowed types
        #   output :data, type: [Hash, Array]
        #
        # @example Define an output with proc default
        #   output :metadata, type: Hash, default: -> { {} }
        def output(name, opts = {})
          Validation.validate_symbol_name!(name, :output, self)
          OptionsValidation.validate!(name, :output, self, opts)
          Validation.validate_reserved_name!(name, :output, self)
          Validation.validate_name_conflicts!(name, :output, self)
          Validation.validate_type_required!(name, :output, self, opts)

          own_outputs[name] = Settings::Field.new(name, self, opts.merge(field_type: FieldTypes::OUTPUT))
          @outputs = nil # Clear memoized outputs since we're modifying them
        end

        # Remove an output from the service
        #
        # @param name [Symbol] the output name to remove
        def remove_output(name)
          own_outputs.delete(name)
          @outputs = nil # Clear memoized outputs since we're modifying them
        end

        # Get all outputs including inherited ones
        #
        # @return [Hash] all outputs defined for this service
        def outputs
          @outputs ||= build_outputs
        end

        # Get only outputs defined in this class
        #
        # @return [Hash] outputs defined in this class only
        def own_outputs
          @own_outputs ||= {}
        end

        private

        # Build outputs by merging inherited outputs with own outputs
        #
        # @return [Hash] merged outputs
        def build_outputs
          inherited = superclass.respond_to?(:outputs) ? superclass.outputs.dup : {}
          inherited.merge(own_outputs)
        end
      end
    end
  end
end
