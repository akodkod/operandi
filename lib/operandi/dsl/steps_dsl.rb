# frozen_string_literal: true

require_relative "../constants"
require_relative "validation"

module Operandi
  module Dsl
    # DSL for defining and managing service steps
    module StepsDsl
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Define a step for the service
        #
        # @param name [Symbol] the step name (must correspond to a private method)
        # @param opts [Hash] options for configuring the step
        # @option opts [Symbol, Proc] :if Condition to determine if step should run
        # @option opts [Symbol, Proc] :unless Condition to skip step (returns truthy to skip)
        # @option opts [Boolean] :always (false) Run step even after errors/warnings
        # @option opts [Symbol] :before Insert this step before the specified step
        # @option opts [Symbol] :after Insert this step after the specified step
        # @option opts [Boolean] :parent Mark the step method as inherited for static analysis
        #
        # @example Define a simple step
        #   step :validate_input
        #
        # @example Define a conditional step
        #   step :send_notification, if: :should_notify?
        #   step :skip_validation, unless: :production?
        #
        # @example Define a step that always runs
        #   step :cleanup, always: true
        #
        # @example Define step ordering
        #   step :log_start, before: :validate_input
        #   step :log_end, after: :process_data
        #
        # @example Define a step with proc condition
        #   step :premium_feature, if: -> { user.premium? && feature_enabled? }
        def step(name, opts = {}) # rubocop:disable Metrics/MethodLength
          Validation.validate_symbol_name!(name, :step, self)
          OptionsValidation.validate!(name, :step, self, opts)
          Validation.validate_reserved_name!(name, :step, self)
          Validation.validate_name_conflicts!(name, :step, self)
          validate_step_opts!(name, opts)

          # Build current steps to check for duplicates and find insertion targets
          current = steps
          if current.key?(name)
            raise Operandi::Error,
                  "Step `#{name}` is already defined in service #{self}. Each step must have a unique name."
          end

          if (target = opts[:before] || opts[:after]) && !current.key?(target)
            available = current.keys.join(", ")
            raise Operandi::Error,
                  "Cannot find target step `#{target}` in service #{self}. Available steps: [#{available}]"
          end

          step_obj = Settings::Step.new(name, self, opts)

          if opts[:before] || opts[:after]
            step_operations << { action: :insert,
                                 name: name,
                                 step: step_obj,
                                 before: opts[:before],
                                 after: opts[:after], }
          else
            step_operations << { action: :add, name: name, step: step_obj }
          end

          # Clear memoized steps since we're modifying them
          @steps = nil
        end

        # Remove a step from the service
        #
        # @param name [Symbol] the step name to remove
        def remove_step(name)
          step_operations << { action: :remove, name: name }

          # Clear memoized steps since we're modifying them
          @steps = nil
        end

        # Get all steps including inherited ones
        #
        # @return [Hash] all steps defined for this service
        def steps
          @steps ||= build_steps
        end

        # Get the list of step operations to be applied
        #
        # @return [Array] list of operations
        def step_operations
          @step_operations ||= []
        end

        # Validate that the service has steps defined
        # Called before executing the service
        #
        # @raise [NoStepsError] if no steps are defined
        def validate_steps!
          return unless steps.empty?

          raise Operandi::NoStepsError,
                "Service #{self} has no steps defined. Define at least one step or implement a `run` method."
        end

        private

        # Validate step options to ensure they are valid
        #
        # @param name [Symbol] the step name
        # @param opts [Hash] the step options
        def validate_step_opts!(name, opts)
          return unless opts[:before] && opts[:after]

          raise Operandi::Error, "You cannot specify `before` and `after` " \
                                 "for step `#{name}` in service #{self} at the same time"
        end

        # Build steps by applying operations to inherited steps
        #
        # @return [Hash] the final steps hash
        def build_steps
          # Start with inherited steps
          result = inherit_steps

          # Apply operations in order
          step_operations.each { |op| apply_step_operation(result, op) }

          # If no steps defined, check for `run` method as fallback
          result[:run] = Settings::Step.new(:run, self, {}) if result.empty? && instance_method_defined?(:run)

          result
        end

        # Check if an instance method is defined in this class or its ancestors
        # (excluding Operandi::Base and its modules)
        #
        # @param method_name [Symbol] the method name to check
        # @return [Boolean] true if the method is defined
        def instance_method_defined?(method_name)
          # Check if method exists and is not from base service classes
          return false unless method_defined?(method_name) || private_method_defined?(method_name)

          # Get the method owner to ensure it's defined in user's service class
          owner = instance_method(method_name).owner

          # Method should be defined in a class that inherits from Base,
          # not in Base itself or its included modules
          !owner.to_s.start_with?("Operandi")
        end

        # Inherit steps from parent class
        #
        # @return [Hash] inherited steps
        def inherit_steps
          superclass.respond_to?(:steps) ? superclass.steps.dup : {}
        end

        # Apply a single step operation to the steps hash
        #
        # @param steps [Hash] the steps hash
        # @param operation [Hash] the operation to apply
        def apply_step_operation(steps, operation)
          case operation[:action]
          when :add
            steps[operation[:name]] = operation[:step]
          when :remove
            steps.delete(operation[:name])
          when :insert
            insert_step(steps, operation)
          end
        end

        # Insert a step before or after a target step
        #
        # @param steps [Hash] the steps hash
        # @param operation [Hash] the insert operation details
        def insert_step(steps, operation)
          target = operation[:before] || operation[:after]
          keys = steps.keys
          index = keys.index(target)
          return unless index

          # More efficient insertion using ordered hash reconstruction
          new_steps = {}

          keys.each_with_index do |key, i|
            # Insert before target
            new_steps[operation[:name]] = operation[:step] if operation[:before] && i == index
            new_steps[key] = steps[key]

            # Insert after target
            new_steps[operation[:name]] = operation[:step] if operation[:after] && i == index
          end

          steps.replace(new_steps)
        end
      end
    end
  end
end
