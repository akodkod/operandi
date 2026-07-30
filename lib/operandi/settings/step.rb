# frozen_string_literal: true

module Operandi
  module Settings
    # Stores configuration for a single service step.
    # Created automatically when using the `step` DSL method.
    class Step
      # @return [Symbol] the step name (method to call)
      attr_reader :name

      # @return [Boolean, nil] true if step runs even after errors/warnings
      attr_reader :always

      # Initialize a new step definition.
      #
      # @param name [Symbol] the step name (must match a method)
      # @param service_class [Class] the service class this step belongs to
      # @param opts [Hash] step options
      # @option opts [Symbol, Proc] :if condition to run the step
      # @option opts [Symbol, Proc] :unless condition to skip the step
      # @option opts [Boolean] :always run even after errors/warnings
      # @raise [Error] if both :if and :unless are specified
      def initialize(name, service_class, opts = {})
        @name = name
        @service_class = service_class

        @if     = opts[:if]
        @unless = opts[:unless]
        @always = opts[:always]

        if @if && @unless
          raise Operandi::Error, "#{service_class} `if` and `unless` cannot be specified " \
                                 "for the step `#{name}` at the same time"
        end
      end

      # Execute the step on the given service instance.
      #
      # @param instance [Base] the service instance
      # @return [Boolean] true if the step was executed, false if skipped
      # @raise [RuntimeError] if the step method is not defined
      def run(instance) # rubocop:disable Naming/PredicateMethod
        return false unless run?(instance)

        unless instance.respond_to?(name, true)
          available_steps = @service_class.steps.keys.join(", ")
          message = "Step method `#{name}` is not defined in #{@service_class}. " \
                    "Defined steps: [#{available_steps}]"
          raise Operandi::RuntimeError.new(message, service: instance)
        end

        execute_with_callbacks(instance)
        true
      end

      private

      def execute_with_callbacks(instance)
        errors_count_before = instance.errors.count

        instance.run_callbacks(:before_step_run, instance, name)

        instance.run_callbacks(:around_step_run, instance, name) do
          instance.send(name)
        end

        instance.run_callbacks(:after_step_run, instance, name)

        if instance.errors.count > errors_count_before
          instance.run_callbacks(:on_step_failure, instance, name)
        else
          instance.run_callbacks(:on_step_success, instance, name)
        end
      rescue StandardError => e
        instance.run_callbacks(:on_step_crash, instance, name, e)
        raise e
      end

      def run?(instance)
        return false if instance.stopped?

        if @if
          check_condition(@if, instance)
        elsif @unless
          !check_condition(@unless, instance)
        else
          true
        end
      end

      def check_condition(condition, instance)
        case condition
        when Symbol
          instance.send(condition)
        when Proc
          instance.instance_exec(&condition)
        else
          message = "#{@service_class} condition should be a Symbol or Proc " \
                    "for the step `#{@name}` (currently: #{condition.class})"
          raise Operandi::RuntimeError.new(message, service: instance)
        end
      end
    end
  end
end
