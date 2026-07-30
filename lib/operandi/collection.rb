# frozen_string_literal: true

require_relative "constants"

module Operandi
  # Collection module for storing argument and output values.
  module Collection
    # Storage for service arguments or outputs with type validation.
    #
    # @example Accessing values
    #   service.arg[:name]     # => "John"
    #   service.output[:user]  # => #<User id: 1>
    class Base
      extend Forwardable

      # @!method key?(key)
      #   Check if a key exists in the collection.
      #   @param key [Symbol] the key to check
      #   @return [Boolean] true if key exists

      # @!method to_h
      #   Convert collection to a hash.
      #   @return [Hash] the stored values
      def_delegators :@storage, :key?, :to_h

      # Initialize a new collection.
      #
      # @param instance [Base] the service instance
      # @param collection_type [String] "arguments" or "outputs"
      # @param storage [Hash] initial values
      # @raise [ArgTypeError] if storage is not a Hash
      def initialize(instance, collection_type, storage = {})
        validate_collection_type!(collection_type)

        @instance = instance
        @collection_type = collection_type
        @storage = storage

        return if storage.is_a?(Hash)

        message = "#{instance.class} - #{collection_type} must be a Hash"
        raise Operandi::ArgTypeError.new(message, service_class: instance.class)
      end

      # Set a value in the collection.
      #
      # @param key [Symbol] the key to set
      # @param value [Object] the value to store
      # @return [Object] the stored value
      def set(key, value)
        @storage[key] = value
      end

      # Get a value from the collection.
      #
      # @param key [Symbol] the key to retrieve
      # @return [Object, nil] the stored value or nil
      def get(key)
        @storage[key]
      end

      # Get a value using bracket notation.
      #
      # @param key [Symbol] the key to retrieve
      # @return [Object, nil] the stored value or nil
      def [](key)
        get(key)
      end

      # Set a value using bracket notation.
      #
      # @param key [Symbol] the key to set
      # @param value [Object] the value to store
      # @return [Object] the stored value
      def []=(key, value)
        set(key, value)
      end

      # Load default values for fields that haven't been set.
      #
      # @return [void]
      def load_defaults
        settings_collection.each do |name, settings|
          next if !settings.default_exists || key?(name)

          if settings.default.is_a?(Proc)
            set(name, @instance.instance_exec(&settings.default))
          else
            set(name, Utils.deep_dup(settings.default))
          end
        end
      end

      # Validate all values against their type definitions.
      #
      # @return [void]
      # @raise [ArgTypeError] if a value fails type validation
      def validate!
        settings_collection.each do |name, field|
          next if field.optional && (!key?(name) || get(name).nil?)

          # validate_type! returns the validated value
          validated_value = field.validate_type!(get(name))

          # Store the validated value back
          set(name, validated_value) if validated_value != get(name)
        end
      end

      # Extend arguments hash with context values from this collection.
      # Only applies to arguments collections.
      #
      # @param args [Hash] arguments hash to extend
      # @return [Hash] the extended arguments hash
      def extend_with_context(args)
        return args unless @collection_type == CollectionTypes::ARGUMENTS

        settings_collection.each do |name, field|
          next if !field.context || args.key?(name) || !key?(name)

          args[field.name] = get(name)
        end

        args
      end

      # Access a value using method call syntax.
      #
      # @param method_name [Symbol] the method name (used as key)
      # @param args [Array] method arguments (must be empty)
      # @return [Object, nil] the stored value or nil
      # @raise [NoMethodError] if the key doesn't exist
      def method_missing(method_name, *args, &)
        return super unless respond_to_missing?(method_name, false)

        get(method_name)
      end

      # Check if a method name corresponds to a stored key.
      #
      # @param method_name [Symbol] the method name to check
      # @param include_private [Boolean] whether to include private methods
      # @return [Boolean] true if the key exists
      def respond_to_missing?(method_name, include_private = false)
        key?(method_name) || settings_collection.key?(method_name) || super
      end

      private

      def validate_collection_type!(type)
        return if CollectionTypes::ALL.include?(type)

        raise ArgumentError,
              "collection_type must be one of #{CollectionTypes::ALL.join(', ')}, got: #{type.inspect}"
      end

      def settings_collection
        @instance.class.public_send(@collection_type)
      end
    end

    # Aliases for backwards compatibility
    Arguments = Base
    Outputs = Base
  end
end
