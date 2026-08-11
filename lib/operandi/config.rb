# frozen_string_literal: true

module Operandi
  class << self
    # Configure Operandi with a block.
    #
    # @yield [Config] the configuration object
    # @return [void]
    #
    # @example
    #   Operandi.configure do |config|
    #     config.require_arg_type = true
    #     config.require_output_type = true
    #     config.use_transactions = false
    #   end
    def configure
      yield config
    end

    # Get the global configuration object.
    #
    # @return [Config] the configuration instance
    def config
      @config ||= Config.new
    end
  end

  # Configuration class for Operandi global settings.
  #
  # @example Accessing configuration
  #   Operandi.config.require_arg_type # => true
  #
  # @example Modifying configuration
  #   Operandi.config.use_transactions = false
  class Config
    # @return [Boolean] whether arguments must have a type specified
    attr_reader :require_arg_type

    # @return [Boolean] whether outputs must have a type specified
    attr_reader :require_output_type

    # @return [Boolean] whether to wrap service execution in a database transaction
    attr_reader :use_transactions

    # @return [Boolean] whether to copy errors to parent service in chain
    attr_reader :load_errors

    # @return [Boolean] whether to stop executing steps when an error is added
    attr_reader :break_on_error

    # @return [Boolean] whether to raise Operandi::RuntimeError when service fails
    attr_reader :raise_on_error

    # @return [Boolean] whether to rollback the transaction when an error is added
    attr_reader :rollback_on_error

    # @return [Boolean] whether to copy warnings to parent service in chain
    attr_reader :load_warnings

    # @return [Boolean] whether to stop executing steps when a warning is added
    attr_reader :break_on_warning

    # @return [Boolean] whether to raise Operandi::RuntimeError when service has warnings
    attr_reader :raise_on_warning

    # @return [Boolean] whether to rollback the transaction when a warning is added
    attr_reader :rollback_on_warning

    # @return [Boolean] whether to replace nil argument values with their defaults
    attr_reader :nil_as_default

    # @return [Hash{String => String}] custom type mappings for Ruby LSP addon.
    #   Maps custom types to Ruby types for hover/completion.
    #   @example { "CustomTypes::UUID" => "String", "CustomTypes::Money" => "BigDecimal" }
    attr_reader :ruby_lsp_type_mappings

    DEFAULTS = {
      require_arg_type: true,
      require_output_type: true,
      use_transactions: true,

      load_errors: true,
      break_on_error: true,
      raise_on_error: false,
      rollback_on_error: true,

      load_warnings: true,
      break_on_warning: false,
      raise_on_warning: false,
      rollback_on_warning: false,

      nil_as_default: false,

      ruby_lsp_type_mappings: {}.freeze,
    }.freeze

    DEFAULTS.each_key do |name|
      define_method(:"#{name}=") do |value|
        instance_variable_set(:"@#{name}", value)
        @to_h = nil # Invalidate memoized hash
      end
    end

    # Convenience setter for backward compatibility.
    # Sets both require_arg_type and require_output_type.
    #
    # @param value [Boolean] whether to require types for arguments and outputs
    # @return [void]
    def require_type=(value)
      self.require_arg_type = value
      self.require_output_type = value
    end

    # Initialize configuration with default values.
    def initialize
      reset_to_defaults!
    end

    # Reset all configuration options to their default values.
    #
    # @return [void]
    def reset_to_defaults!
      DEFAULTS.each do |key, value|
        instance_variable_set(:"@#{key}", value)
      end

      @to_h = nil # Invalidate memoized hash
    end

    # Convert configuration to a hash.
    #
    # @return [Hash{Symbol => Object}] all configuration options as a hash
    def to_h
      @to_h ||= DEFAULTS.keys.to_h do |key|
        [key, public_send(key)]
      end
    end

    # Merge configuration with additional options.
    #
    # @param config [Hash] options to merge
    # @return [Hash] merged configuration hash
    def merge(config)
      to_h.merge(config)
    end
  end
end
