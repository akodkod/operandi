# frozen_string_literal: true

require "operandi/constants"
require "operandi/message"
require "operandi/messages"
require "operandi/base_with_context"

require "operandi/settings/step"
require "operandi/settings/field"

require "operandi/collection"

require "operandi/dsl/arguments_dsl"
require "operandi/dsl/outputs_dsl"
require "operandi/dsl/steps_dsl"

require "operandi/concerns/execution"
require "operandi/concerns/state_management"
require "operandi/concerns/parent_service"

# Base class for all service objects
module Operandi
  # Base class for building service objects with arguments, outputs, and steps.
  #
  # @example Basic service
  #   class CreateUser < Operandi::Base
  #     arg :name, type: String
  #     arg :email, type: String
  #
  #     output :user, type: User
  #
  #     step :create_user
  #
  #     private
  #
  #     def create_user
  #       self.user = User.create!(name: name, email: email)
  #     end
  #   end
  #
  #   result = CreateUser.run(name: "John", email: "john@example.com")
  #   result.success? # => true
  #   result.user     # => #<User id: 1, name: "John">
  class Base
    extend CallbackDsl
    include Callbacks
    include Dsl::ArgumentsDsl
    include Dsl::OutputsDsl
    include Dsl::StepsDsl
    include Concerns::Execution
    include Concerns::StateManagement
    include Concerns::ParentService

    # @return [Collection::Base] collection of output values
    attr_reader :outputs

    # @return [Collection::Base] collection of argument values
    attr_reader :arguments

    alias arg arguments
    alias output outputs

    # @return [Messages] collection of error messages
    attr_reader :errors

    # @return [Messages] collection of warning messages
    attr_reader :warnings

    # Initialize a new service instance.
    #
    # @param args [Hash] arguments to pass to the service
    # @param config [Hash] runtime configuration overrides
    # @param parent_service [Base, nil] parent service for nested calls
    def initialize(args = {}, config = {}, parent_service = nil)
      @config = Operandi.config.merge(self.class.class_config || {}).merge(config)
      @parent_service = parent_service

      @outputs = Collection::Base.new(self, CollectionTypes::OUTPUTS)
      @arguments = Collection::Base.new(self, CollectionTypes::ARGUMENTS, args.dup)

      @stopped = false
      @launched_steps = []

      initialize_errors
      initialize_warnings
    end

    # Check if the service completed without errors.
    #
    # @return [Boolean] true if no errors were added
    def success?
      !errors?
    end
    alias successful? success?

    # Check if the service completed with errors.
    #
    # @return [Boolean] true if any errors were added
    def failed?
      errors?
    end

    # Check if the service has any errors.
    #
    # @return [Boolean] true if errors collection is not empty
    def errors?
      @errors.any?
    end

    # Check if the service has any warnings.
    #
    # @return [Boolean] true if warnings collection is not empty
    def warnings?
      @warnings.any?
    end

    # Stop executing remaining steps after the current step completes.
    #
    # @return [Boolean] true
    def stop!
      @stopped = true
    end
    alias done! stop!

    # Check if the service has been stopped.
    #
    # @return [Boolean] true if stop! was called
    def stopped?
      @stopped
    end
    alias done? stopped?

    # Stop execution immediately, skipping any remaining code in the current step.
    #
    # @raise [StopExecution] always raises to halt execution
    # @return [void]
    def stop_immediately!
      @stopped = true
      raise Operandi::StopExecution
    end

    # Add an error to the :base key.
    #
    # @param message [String] the error message
    # @return [void]
    def fail!(message)
      errors.add(:base, message)
    end

    # Add an error and stop execution immediately, causing transaction rollback.
    # Steps marked with `always: true` will still run after this method is called.
    #
    # @param message [String] the error message
    # @raise [FailExecution] always raises to halt execution and rollback
    # @return [void]
    def fail_immediately!(message)
      errors.add(:base, message, rollback: false)
      raise Operandi::FailExecution
    end

    # Execute the service steps.
    #
    # @return [void]
    # @raise [StandardError] re-raises any exception after running always steps
    def call
      load_defaults_and_validate

      run_callbacks(:before_service_run, self)

      run_callbacks(:around_service_run, self) do
        execute_service
      end

      run_service_result_callbacks
    rescue StandardError => e
      run_steps_with_always
      raise e
    end

    class << self
      # @return [Hash, nil] class-level configuration options
      attr_accessor :class_config

      # Set class-level configuration for this service.
      #
      # @param config [Hash] configuration options
      # @return [Hash] the configuration hash
      def config(config = {})
        self.class_config = config
      end

      # Run the service and return the result.
      #
      # @param kwargs [Hash] keyword arguments matching service arguments
      # @return [Base] the executed service instance
      #
      # @example
      #   result = MyService.run(name: "test")
      #   result.success? # => true
      def run(**kwargs)
        new(kwargs).tap(&:call)
      end

      # Run the service and raise an error if it fails.
      #
      # @param kwargs [Hash] keyword arguments matching service arguments
      # @return [Base] the executed service instance
      # @raise [Error] if the service fails
      #
      # @example
      #   MyService.run!(name: "test") # raises if service fails
      def run!(**kwargs)
        new(kwargs, { raise_on_error: true }).tap(&:call)
      end

      # Create a context for running the service with a parent service or config.
      #
      # @param service_or_config [Base, Hash] parent service or configuration hash
      # @param config [Hash] configuration hash (when first param is a service)
      # @return [BaseWithContext] context wrapper for running the service
      #
      # @example With parent service
      #   ChildService.with(self).run(data: value)
      #
      # @example With configuration
      #   MyService.with(use_transactions: false).run(name: "test")
      def with(service_or_config, config = {})
        service = service_or_config.is_a?(Hash) ? nil : service_or_config
        config = service_or_config unless service

        BaseWithContext.new(self, service, config.dup)
      end
    end
  end
end
