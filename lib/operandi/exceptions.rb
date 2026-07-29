# frozen_string_literal: true

module Operandi
  # Base exception class for all Operandi errors.
  class Error < StandardError; end

  # Raised when an argument or output value doesn't match the expected type.
  class ArgTypeError < Error; end

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
