# frozen_string_literal: true

module Operandi
  # Collection type constants
  module CollectionTypes
    ARGUMENTS = :arguments
    OUTPUTS = :outputs

    ALL = [ARGUMENTS, OUTPUTS].freeze
  end

  # Field type constants
  module FieldTypes
    ARGUMENT = :argument
    OUTPUT = :output

    ALL = [ARGUMENT, OUTPUT].freeze
  end

  # Reserved names that cannot be used for arguments, outputs, or steps
  # These names would conflict with existing gem methods
  module ReservedNames
    # Instance methods from Base class and concerns
    BASE_METHODS = [
      :arg,
      :output,
      :errors,
      :warnings,
      :success?,
      :failed?,
      :errors?,
      :warnings?,
      :stop!,
      :stopped?,
      :stop_immediately!,
      :call,
      :run_callbacks,
      :initialize,
      :successful?,
      :fail!,
      :fail_immediately!,
      :execute_service,
      :run_service_result_callbacks,
      :run_steps,
      :run_steps_with_always,
      :launch_step,
      :load_defaults_and_validate,
      :within_transaction,
      :initialize_errors,
      :initialize_warnings,
      :copy_errors_to_parent_service,
      :copy_warnings_to_parent_service,
      :run_simple_callbacks,
      :run_around_callbacks,
      :execute_callback,
    ].freeze

    # Class methods that could conflict
    CLASS_METHODS = [
      :config,
      :run,
      :run!,
      :with,
      :arg,
      :remove_arg,
      :output,
      :remove_output,
      :step,
      :remove_step,
      :steps,
      :outputs,
      :arguments,
    ].freeze

    # Callback method names
    CALLBACK_METHODS = [
      :before_step_run,
      :after_step_run,
      :around_step_run,
      :on_step_success,
      :on_step_failure,
      :on_step_crash,
      :before_service_run,
      :after_service_run,
      :around_service_run,
      :on_service_success,
      :on_service_failure,
    ].freeze

    # Ruby reserved words and common Object methods
    RUBY_RESERVED = [
      :initialize,
      :class,
      :object_id,
      :send,
      :__send__,
      :public_send,
      :respond_to?,
      :method,
      :methods,
      :instance_variable_get,
      :instance_variable_set,
      :instance_variables,
      :extend,
      :include,
      :new,
      :allocate,
      :superclass,
    ].freeze

    # All reserved names combined (used for validation)
    ALL = (BASE_METHODS + CALLBACK_METHODS + RUBY_RESERVED).uniq.freeze
  end
end
