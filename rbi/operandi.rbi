# typed: strict
# frozen_string_literal: true

# RBI signatures for Operandi gem.
# These signatures provide Sorbet type checking without requiring sorbet-runtime as a dependency.

module Operandi
  class Base
    # Attributes
    sig { returns(Operandi::Messages) }
    def errors; end

    sig { returns(Operandi::Messages) }
    def warnings; end

    # Instance methods
    sig { returns(T::Boolean) }
    def success?; end

    sig { returns(T::Boolean) }
    def successful?; end

    sig { returns(T::Boolean) }
    def failed?; end

    sig { returns(T::Boolean) }
    def errors?; end

    sig { returns(T::Boolean) }
    def warnings?; end

    sig { void }
    def stop!; end

    sig { returns(T::Boolean) }
    def stopped?; end

    sig { returns(T.noreturn) }
    def stop_immediately!; end

    sig { params(message: String).void }
    def fail!(message); end

    sig { params(message: String).returns(T.noreturn) }
    def fail_immediately!(message); end

    sig { void }
    def call; end

    # Class methods
    class << self
      sig { returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def class_config; end

      sig { params(class_config: T.nilable(T::Hash[Symbol, T.untyped])).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def class_config=(class_config); end

      sig { params(config: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def config(config = {}); end

      sig { params(kwargs: T.untyped).returns(T.attached_class) }
      def run(**kwargs); end

      sig { params(kwargs: T.untyped).returns(T.attached_class) }
      def run!(**kwargs); end

      sig {
        params(
          service_or_config: T.any(Operandi::Base, T::Hash[Symbol, T.untyped]),
          config: T::Hash[Symbol, T.untyped],
        ).returns(Operandi::BaseWithContext)
      }
      def with(service_or_config, config = {}); end
    end
  end

  class BaseWithContext
    sig {
      params(
        service_class: T.class_of(Operandi::Base),
        parent_service: T.nilable(Operandi::Base),
        config: T::Hash[Symbol, T.untyped],
      ).void
    }
    def initialize(service_class, parent_service, config); end

    sig { params(kwargs: T.untyped).returns(Operandi::Base) }
    def run(**kwargs); end

    sig { params(kwargs: T.untyped).returns(Operandi::Base) }
    def run!(**kwargs); end
  end

  class Messages
    sig { params(config: T::Hash[Symbol, T.untyped]).void }
    def initialize(config); end

    sig { params(key: Symbol).returns(T.nilable(T::Array[Operandi::Message])) }
    def [](key); end

    sig { returns(T::Boolean) }
    def any?; end

    sig { returns(T::Boolean) }
    def empty?; end

    sig { returns(Integer) }
    def size; end

    sig { returns(Integer) }
    def count; end

    sig { returns(T::Array[Symbol]) }
    def keys; end

    sig { params(key: Symbol).returns(T::Boolean) }
    def key?(key); end

    sig { params(key: Symbol).returns(T::Boolean) }
    def has_key?(key); end

    sig {
      params(
        key: Symbol,
        texts: T.any(String, T::Array[String], Operandi::Message),
        opts: T::Hash[Symbol, T.untyped],
      ).void
    }
    def add(key, texts, opts = {}); end

    sig { returns(T::Boolean) }
    def break?; end

    sig { params(entity: T.untyped, opts: T::Hash[Symbol, T.untyped]).void }
    def copy_from(entity, opts = {}); end

    sig { params(entity: T.untyped, opts: T::Hash[Symbol, T.untyped]).void }
    def from_record(entity, opts = {}); end

    sig { returns(T::Hash[Symbol, T::Array[String]]) }
    def to_h; end
  end

  module Collection
    class Base
      sig { params(key: Symbol).returns(T::Boolean) }
      def key?(key); end

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def to_h; end

      sig { params(key: Symbol, value: T.untyped).returns(T.untyped) }
      def set(key, value); end

      sig { params(key: Symbol).returns(T.untyped) }
      def get(key); end

      sig { params(key: Symbol).returns(T.untyped) }
      def [](key); end

      sig { params(key: Symbol, value: T.untyped).returns(T.untyped) }
      def []=(key, value); end

      sig { void }
      def load_defaults; end

      sig { void }
      def validate!; end

      sig { params(args: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def extend_with_context(args); end
    end
  end
end
