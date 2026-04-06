# frozen_string_literal: true

module Operandi
  module Concerns
    # Handles service execution logic including steps and validation
    module Execution
      private

      # Execute the main service logic
      def execute_service
        self.class.validate_steps!
        run_steps
        run_steps_with_always
        @output.validate! if success?

        copy_warnings_to_parent_service
        copy_errors_to_parent_service
      end

      # Run all service result callbacks based on success/failure
      def run_service_result_callbacks
        run_callbacks(:after_service_run, self)

        if success?
          run_callbacks(:on_service_success, self)
        else
          run_callbacks(:on_service_failure, self)
        end
      end

      # Run normal steps within transaction
      def run_steps
        within_transaction do
          # Cache steps once for both normal and always execution
          @cached_steps = self.class.steps

          @cached_steps.each do |name, step|
            @launched_steps << name if step.run(self)

            break if @errors.break? || @warnings.break?
          end
        rescue Operandi::StopExecution
          # Gracefully handle stop_immediately! inside transaction to prevent rollback
          @stopped = true
        end
      rescue Operandi::FailExecution
        # FailExecution bubbles out of transaction (causing rollback) but is caught here
        nil
      end

      # Run steps with parameter `always` if they weren't launched because of errors/warnings
      def run_steps_with_always
        # Use cached steps from run_steps, or get them if run_steps wasn't called
        steps_to_check = @cached_steps || self.class.steps

        steps_to_check.each do |name, step|
          next if !step.always || @launched_steps.include?(name)

          @launched_steps << name if step.run(self)
        end
      end

      # Load defaults for outputs and arguments, then validate arguments
      def load_defaults_and_validate
        @output.load_defaults
        @arg.load_defaults
        @arg.validate!
      end

      # Execute block within transaction if configured
      def within_transaction(&)
        if @config[:use_transactions] && defined?(ActiveRecord::Base)
          ActiveRecord::Base.transaction(requires_new: true, &)
        else
          yield
        end
      end
    end
  end
end
