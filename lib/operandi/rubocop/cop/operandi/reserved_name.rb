# frozen_string_literal: true

require_relative "../../../../operandi/constants"

module RuboCop
  module Cop
    module Operandi
      # Ensures that `arg`, `step`, and `output` declarations do not use reserved names
      # that would conflict with Operandi methods.
      #
      # @example
      #   # bad
      #   arg :errors, type: Array
      #   arg :output, type: Hash
      #   step :call
      #   output :success?, type: [TrueClass, FalseClass]
      #
      #   # good
      #   arg :validation_errors, type: Array
      #   arg :result_output, type: Hash
      #   step :execute
      #   output :succeeded, type: [TrueClass, FalseClass]
      #
      class ReservedName < Base
        include RuboCop::Cop::RangeHelp

        MSG = "`%<name>s` is a reserved name and cannot be used as %<field_type>s. " \
              "It conflicts with Operandi methods."

        SEVERITY = :error

        RESTRICT_ON_SEND = [:arg, :step, :output].freeze

        FIELD_TYPE_NAMES = {
          arg: "an argument",
          step: "a step",
          output: "an output",
        }.freeze

        # @!method dsl_call?(node)
        def_node_matcher :dsl_call?, <<~PATTERN
          (send nil? ${:arg :step :output} (sym $_) ...)
        PATTERN

        def on_send(node)
          dsl_call?(node) do |method_name, name|
            return unless ::Operandi::ReservedNames::ALL.include?(name)

            field_type = FIELD_TYPE_NAMES[method_name]
            add_offense(node, message: format(MSG, name: name, field_type: field_type), severity: SEVERITY)
          end
        end
      end
    end
  end
end
