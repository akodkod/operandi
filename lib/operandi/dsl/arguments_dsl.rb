# frozen_string_literal: true

require_relative "../constants"
require_relative "validation"

module Operandi
  module Dsl
    # DSL for defining and managing service arguments
    module ArgumentsDsl
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Define an argument for the service
        #
        # @param name [Symbol] the argument name
        # @param opts [Hash] options for configuring the argument
        # @option opts [Class, Array<Class>] :type Type(s) to validate against
        #   (e.g., String, Integer, [String, Symbol])
        # @option opts [Boolean] :optional (false) Whether nil values are allowed
        # @option opts [Object, Proc] :default Default value or proc to evaluate in instance context
        # @option opts [Boolean] :context (false) Whether to pass this argument to child services
        #
        # @example Define a required string argument
        #   arg :name, type: String
        #
        # @example Define an optional argument with default
        #   arg :age, type: Integer, optional: true, default: 25
        #
        # @example Define an argument with multiple allowed types
        #   arg :id, type: [String, Integer]
        #
        # @example Define an argument with proc default
        #   arg :timestamp, type: Time, default: -> { Time.now }
        #
        # @example Define a context argument passed to child services
        #   arg :current_user, type: User, context: true
        def arg(name, opts = {})
          Validation.validate_symbol_name!(name, :argument, self)
          OptionsValidation.validate!(name, :argument, self, opts)
          Validation.validate_reserved_name!(name, :argument, self)
          Validation.validate_name_conflicts!(name, :argument, self)
          Validation.validate_type_required!(name, :argument, self, opts)

          own_arguments[name] = Settings::Field.new(name, self, opts.merge(field_type: FieldTypes::ARGUMENT))
          @arguments = nil # Clear memoized arguments since we're modifying them
        end

        # Remove an argument from the service
        #
        # @param name [Symbol] the argument name to remove
        def remove_arg(name)
          own_arguments.delete(name)
          @arguments = nil # Clear memoized arguments since we're modifying them
        end

        # Get all arguments including inherited ones
        #
        # @return [Hash] all arguments defined for this service
        def arguments
          @arguments ||= build_arguments
        end

        # Get only arguments defined in this class
        #
        # @return [Hash] arguments defined in this class only
        def own_arguments
          @own_arguments ||= {}
        end

        private

        # Build arguments by merging inherited arguments with own arguments
        #
        # @return [Hash] merged arguments
        def build_arguments
          inherited = superclass.respond_to?(:arguments) ? superclass.arguments.dup : {}
          inherited.merge(own_arguments)
        end
      end
    end
  end
end
