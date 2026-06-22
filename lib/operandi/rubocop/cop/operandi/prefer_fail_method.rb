# frozen_string_literal: true

module RuboCop
  module Cop
    module Operandi
      # Detects `errors.add(:base, "message")` and suggests using `fail!("message")` instead.
      #
      # This cop checks calls inside service classes that inherit from
      # Operandi::Base or any configured base service classes.
      #
      # @safety
      #   This cop's autocorrection is safe as `fail!` is a wrapper method
      #   that calls `errors.add(:base, message)` internally.
      #
      # @example
      #   # bad
      #   class User::Create < ApplicationService
      #     step :process
      #
      #     private
      #
      #     def process
      #       errors.add(:base, "user is required")
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
      #       fail!("user is required")
      #     end
      #   end
      #
      class PreferFailMethod < Base
        extend AutoCorrector

        MSG = "Use `fail!(...)` instead of `errors.add(:base, ...)`."

        def_node_matcher :errors_add_base?, <<~PATTERN
          (send
            (send nil? :errors) :add
            (sym :base)
            ...)
        PATTERN

        DEFAULT_BASE_CLASSES = ["ApplicationService"].freeze

        def on_class(node)
          @in_service_class = service_class?(node)
        end

        def after_class(_node)
          @in_service_class = false
        end

        def on_send(node)
          return unless @in_service_class
          return unless node.method_name == :add

          return unless errors_add_base?(node)

          # Only flag if there's a message argument after :base
          # errors.add(:base) without a message is invalid Operandi syntax
          message_args = node.arguments[1..]
          return if message_args.empty?

          add_offense(node, message: MSG) do |corrector|
            autocorrect(corrector, node, message_args)
          end
        end

        private

        def autocorrect(corrector, node, message_args)
          # Get the source code for all arguments after the :base symbol
          args_source = message_args.map(&:source).join(", ")
          replacement = "fail!(#{args_source})"

          corrector.replace(node, replacement)
        end

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
      end
    end
  end
end
