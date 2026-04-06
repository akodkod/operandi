# frozen_string_literal: true

module RuboCop
  module Cop
    module Operandi
      # Detects deprecated `arguments` and `outputs` accessor calls and suggests
      # using `arg` and `output` instead.
      #
      # This cop checks calls inside service classes that inherit from
      # Operandi::Base or any configured base service classes.
      #
      # @safety
      #   This cop's autocorrection is safe as `arguments` and `outputs` are
      #   direct wrappers for `arg` and `output`.
      #
      # @example
      #   # bad
      #   class User::Create < ApplicationService
      #     step :process
      #
      #     private
      #
      #     def process
      #       arguments[:name]
      #       outputs[:result]
      #     end
      #   end
      #
      #   # good
      #   class User::Create < ApplicationService
      #     step :process
      #
      #     private
      #
      #     def process
      #       arg[:name]
      #       output[:result]
      #     end
      #   end
      #
      class DeprecatedAccessors < Base
        extend AutoCorrector

        MSG_ARGUMENTS = "Use `arg` instead of deprecated `arguments`."
        MSG_OUTPUTS = "Use `output` instead of deprecated `outputs`."

        RESTRICT_ON_SEND = [:arguments, :outputs].freeze

        REPLACEMENTS = {
          arguments: :arg,
          outputs: :output,
        }.freeze

        DEFAULT_BASE_CLASSES = ["ApplicationService"].freeze

        def on_class(node)
          @in_service_class = service_class?(node)
        end

        def after_class(_node)
          @in_service_class = false
        end

        def on_send(node)
          return unless @in_service_class
          return unless RESTRICT_ON_SEND.include?(node.method_name)
          return if node.receiver && !self_receiver?(node)

          message = node.method_name == :arguments ? MSG_ARGUMENTS : MSG_OUTPUTS
          replacement = REPLACEMENTS[node.method_name]

          add_offense(node, message: message) do |corrector|
            if node.receiver
              corrector.replace(node, "self.#{replacement}")
            else
              corrector.replace(node, replacement.to_s)
            end
          end
        end

        private

        def service_class?(node)
          return false unless node.parent_class

          parent_class_name = extract_class_name(node.parent_class)
          return false unless parent_class_name

          # Check for direct Operandi::Base inheritance
          return true if parent_class_name == "Operandi::Base"

          # Check against configured base service classes
          base_classes = cop_config.fetch("BaseServiceClasses", DEFAULT_BASE_CLASSES)
          base_classes.include?(parent_class_name)
        end

        def extract_class_name(node)
          case node.type
          when :const
            node.const_name
          when :send
            # For namespaced constants like Operandi::Base
            node.source
          end
        end

        def self_receiver?(node)
          node.receiver&.self_type?
        end
      end
    end
  end
end
