# frozen_string_literal: true

require_relative "indexing_enhancement"
require_relative "definition"

# Declare version compatibility without runtime dependency on ruby-lsp
RubyLsp::Addon.depend_on_ruby_lsp!("~> 0.26")

module RubyLsp
  module Operandi
    class Addon < ::RubyLsp::Addon
      def activate(global_state, message_queue)
        @global_state = global_state
        @message_queue = message_queue
      end

      def deactivate; end

      def name
        "Ruby LSP Operandi"
      end

      def version
        ::Operandi::VERSION
      end

      # Called on every "go to definition" request
      # Provides navigation from step DSL symbols to their method definitions
      def create_definition_listener(response_builder, uri, node_context, dispatcher)
        return unless @global_state

        Definition.new(response_builder, uri, node_context, @global_state.index, dispatcher)
      end
    end
  end
end
