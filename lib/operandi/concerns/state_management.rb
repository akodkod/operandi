# frozen_string_literal: true

module Operandi
  module Concerns
    # Manages service state including errors and warnings initialization
    module StateManagement
      private

      # Initialize errors collection with configuration
      def initialize_errors
        @errors = Messages.new(
          {
            break_on_add: @config[:break_on_error],
            raise_on_add: @config[:raise_on_error],
            rollback_on_add: @config[:use_transactions] && @config[:rollback_on_error],
          },
          service: self,
        )
      end

      # Initialize warnings collection with configuration
      def initialize_warnings
        @warnings = Messages.new(
          {
            break_on_add: @config[:break_on_warning],
            raise_on_add: @config[:raise_on_warning],
            rollback_on_add: @config[:use_transactions] && @config[:rollback_on_warning],
          },
          service: self,
        )
      end
    end
  end
end
