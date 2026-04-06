# frozen_string_literal: true

module Operandi
  # Wrapper for running a service with a parent context or custom configuration.
  # Created via {Base.with} method.
  #
  # @example Running with parent service context
  #   ChildService.with(self).run(data: value)
  #
  # @example Running with custom configuration
  #   MyService.with(use_transactions: false).run(name: "test")
  class BaseWithContext
    # Initialize a new context wrapper.
    #
    # @param service_class [Class] the service class to run
    # @param parent_service [Base, nil] parent service for error/warning propagation
    # @param config [Hash] configuration overrides
    # @raise [ArgTypeError] if parent_service is not a Base subclass
    def initialize(service_class, parent_service, config)
      @service_class = service_class
      @config = config
      @parent_service = parent_service

      return if parent_service.nil? || parent_service.is_a?(Operandi::Base)

      raise Operandi::ArgTypeError, "#{parent_service.class} - must be a subclass of Operandi::Base"
    end

    # Run the service with the configured context.
    #
    # @param kwargs [Hash] keyword arguments matching service arguments
    # @return [Base] the executed service instance
    def run(**kwargs)
      @service_class.new(extend_arguments(kwargs), @config, @parent_service).tap(&:call)
    end

    # Run the service and raise an error if it fails.
    #
    # @param kwargs [Hash] keyword arguments matching service arguments
    # @return [Base] the executed service instance
    # @raise [Error] if the service fails
    def run!(**kwargs)
      @config[:raise_on_error] = true
      run(**kwargs)
    end

    private

    def extend_arguments(args)
      args = @parent_service.arg.dup.extend_with_context(args) if @parent_service
      args[:deepness] += 1 if args[:deepness]

      args
    end
  end
end
