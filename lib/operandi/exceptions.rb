# frozen_string_literal: true

module Operandi
  # Base exception class for all Operandi errors.
  class Error < StandardError; end

  # Raised for failures that occur while a service instance is running.
  class RuntimeError < Error
    # @return [Base] the service instance that raised the error
    attr_reader :service

    # @param message [String, nil] the error message
    # @param service [Base] the service instance that raised the error
    def initialize(message = nil, service:)
      raise ArgumentError, "service is required" unless service

      unless defined?(Operandi::Base) && service.is_a?(Operandi::Base)
        raise ArgumentError, "service must be an Operandi::Base instance"
      end

      @service = service
      super(message)
    end
  end

  # Raised when an argument or output value doesn't match the expected type.
  class ArgTypeError < Error
    # @return [Class<Base>] the service class associated with the type error
    attr_reader :service_class

    # @param message [String, nil] the error message
    # @param service_class [Class<Base>] the service class associated with the type error
    def initialize(message = nil, service_class:)
      raise ArgumentError, "service_class is required" unless service_class

      unless defined?(Operandi::Base) &&
             service_class.is_a?(Class) &&
             service_class <= Operandi::Base
        raise ArgumentError, "service_class must be an Operandi::Base subclass"
      end

      @service_class = service_class
      super(message)
    end
  end

  # Raised when using a reserved name for an argument, output, or step.
  class ReservedNameError < Error; end

  # Raised when a name is invalid (e.g., not a Symbol).
  class InvalidNameError < Error; end

  # Raised when a service has no steps defined and no run method.
  class NoStepsError < Error; end

  # Raised when type is required but not specified for an argument or output.
  class MissingTypeError < Error; end

  # Control flow exception for stop_immediately!
  # Not an error - used to halt execution gracefully.
  class StopExecution < StandardError; end

  # Control flow exception for fail_immediately!
  # Unlike StopExecution, this exception causes transaction rollback.
  class FailExecution < StandardError; end
end
