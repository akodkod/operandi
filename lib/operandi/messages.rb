# frozen_string_literal: true

module Operandi
  # Collection of error or warning messages, organized by key.
  #
  # @example Adding and accessing errors
  #   errors.add(:name, "can't be blank")
  #   errors.add(:email, "is invalid")
  #   errors[:name]  # => [#<Message key: :name, text: "can't be blank">]
  #   errors.to_h    # => { name: ["can't be blank"], email: ["is invalid"] }
  class Messages
    extend Forwardable

    # @!method [](key)
    #   Get messages for a specific key.
    #   @param key [Symbol] the key to look up
    #   @return [Array<Message>, nil] array of messages or nil

    # @!method any?
    #   Check if there are any messages.
    #   @return [Boolean] true if messages exist

    # @!method empty?
    #   Check if the collection is empty.
    #   @return [Boolean] true if no messages

    # @!method size
    #   Get number of keys with messages.
    #   @return [Integer] number of keys

    # @!method keys
    #   Get all keys with messages.
    #   @return [Array<Symbol>] array of keys

    # @!method key?(key)
    #   Check if a key has messages.
    #   @param key [Symbol] the key to check
    #   @return [Boolean] true if key has messages
    def_delegators :@messages, :[], :any?, :empty?, :size, :keys, :values, :each, :each_with_index, :each_with_object, :key?
    alias has_key? key?

    # Initialize a new messages collection.
    #
    # @param config [Hash] configuration options
    # @option config [Boolean] :break_on_add stop execution when message added
    # @option config [Boolean] :raise_on_add raise exception when message added
    # @option config [Boolean] :rollback_on_add rollback transaction when message added
    def initialize(config)
      @break = false
      @config = config
      @messages = {}
    end

    # Get total count of all messages across all keys.
    #
    # @return [Integer] total number of messages
    def count
      @messages.values.sum(&:size)
    end

    # Add a message to the collection.
    #
    # @param key [Symbol] the key/field for this message
    # @param texts [String, Array<String>, Message] the message text(s) to add
    # @param opts [Hash] additional options
    # @option opts [Boolean] :break override break behavior for this message
    # @option opts [Boolean] :rollback override rollback behavior for this message
    # @return [void]
    # @raise [Error] if text is nil or empty
    #
    # @example Add a single error
    #   errors.add(:name, "can't be blank")
    #
    # @example Add multiple errors
    #   errors.add(:email, ["is invalid", "is already taken"])
    def add(key, texts, opts = {})
      raise Operandi::Error, "Error must be a non-empty string" unless texts

      message = nil

      [*texts].each do |text|
        message = text.is_a?(Message) ? text : Message.new(key, text, opts)

        raise Operandi::Error, "Error must be a non-empty string" unless valid_error_text?(message.text)

        @messages[key] ||= []
        @messages[key] << message
      end

      raise!(message)
      break!(opts.key?(:break) ? opts[:break] : message.break?)
      rollback!(opts.key?(:rollback) ? opts[:rollback] : message.rollback?) if !opts.key?(:last) || opts[:last]
    end

    # Check if step execution should stop.
    #
    # @return [Boolean] true if a message triggered a break
    def break?
      @break
    end

    # Copy messages from another source.
    #
    # @param entity [ActiveRecord::Base, Base, Hash, #each] source to copy from
    # @param opts [Hash] options to pass to each added message
    # @return [void]
    # @raise [Error] if entity type is not supported
    #
    # @example Copy from ActiveRecord model
    #   errors.copy_from(user) # copies user.errors
    #
    # @example Copy from another service
    #   errors.copy_from(child_service)
    def copy_from(entity, opts = {})
      if defined?(ActiveRecord::Base) && entity.is_a?(ActiveRecord::Base)
        copy_from(entity.errors.messages, opts)
      elsif entity.is_a?(Operandi::Base)
        copy_from(entity.errors, opts)
      elsif entity.respond_to?(:each)
        last_index = entity.size - 1

        entity.each_with_index do |(key, message), index|
          add(key, message, opts.merge(last: index == last_index))
        end
      else
        raise Operandi::Error, "Don't know how to import errors from #{entity}"
      end
    end
    alias from_record copy_from

    # Convert messages to a hash with string values.
    #
    # @return [Hash{Symbol => Array<String>}] messages as hash
    def to_h
      @messages.to_h.transform_values { |value| value.map(&:to_s) }
    end

    private

    def valid_error_text?(text)
      return false unless text.is_a?(String)

      !text.strip.empty?
    end

    def break!(break_execution)
      return unless break_execution.nil? ? @config[:break_on_add] : break_execution

      @break = true
    end

    def raise!(message)
      return unless @config[:raise_on_add]

      raise Operandi::Error, "#{message.key.to_s.capitalize} #{message}"
    end

    def rollback!(rollback)
      return if !defined?(ActiveRecord::Rollback) || !(rollback.nil? ? @config[:rollback_on_add] : rollback)

      raise ActiveRecord::Rollback
    end
  end
end
