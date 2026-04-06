# frozen_string_literal: true

module RuboCop
  module Cop
    module Operandi
      # Enforces a consistent order for DSL declarations in service classes.
      #
      # The expected order is: `config` → `arg` → `step` → `output`
      #
      # @safety
      #   This cop's autocorrection is safe but may change the visual grouping of your code.
      #
      # @example
      #   # bad
      #   class MyService < ApplicationService
      #     step :process
      #     arg :name, type: String
      #     output :result, type: Hash
      #     config raise_on_error: true
      #   end
      #
      #   # good
      #   class MyService < ApplicationService
      #     config raise_on_error: true
      #
      #     arg :name, type: String
      #
      #     step :process
      #
      #     output :result, type: Hash
      #   end
      #
      class DslOrder < Base
        extend AutoCorrector

        MSG = "`%<current>s` should come before `%<previous>s`. " \
              "Expected order: config → arg → step → output."

        DSL_METHODS = [:config, :arg, :step, :output].freeze
        DSL_ORDER = { config: 0, arg: 1, step: 2, output: 3 }.freeze

        def on_class(node)
          @dsl_calls = []
          @class_node = node
        end

        def on_send(node)
          return unless dsl_call?(node)

          @dsl_calls ||= []
          @dsl_calls << { method: node.method_name, node: node }
        end

        def after_class(_node)
          return unless @dsl_calls&.any?

          check_order
        end

        private

        def dsl_call?(node)
          node.send_type? &&
            node.receiver.nil? &&
            DSL_METHODS.include?(node.method_name) &&
            class_level?(node)
        end

        def class_level?(node)
          node.each_ancestor(:def, :defs, :block).none?
        end

        def check_order
          highest_order_seen = -1
          highest_method_seen = nil
          has_offense = false

          @dsl_calls.each do |call|
            current_order = DSL_ORDER[call[:method]]

            if current_order < highest_order_seen
              has_offense = true
              add_offense(
                call[:node],
                message: format(MSG, current: call[:method], previous: highest_method_seen),
              ) do |corrector|
                reorder_dsl_declarations(corrector) unless @corrected
                @corrected = true
              end
            elsif current_order > highest_order_seen
              highest_order_seen = current_order
              highest_method_seen = call[:method]
            end
          end

          @corrected = false if has_offense
        end

        def reorder_dsl_declarations(corrector) # rubocop:disable Metrics/AbcSize
          # Collect all DSL nodes with their source including leading comments
          dsl_sources = @dsl_calls.map do |call|
            {
              method: call[:method],
              node: call[:node],
              source: source_with_leading_comment(call[:node]),
            }
          end

          # Sort by expected order
          sorted_sources = dsl_sources.sort_by { |item| DSL_ORDER[item[:method]] }

          # Group by type to add blank lines between groups
          grouped_source = build_grouped_source(sorted_sources)

          # Calculate the range to replace (from first DSL to last DSL)
          first_node = @dsl_calls.min_by { |c| c[:node].loc.expression.begin_pos }[:node]
          last_node = @dsl_calls.max_by { |c| c[:node].loc.expression.end_pos }[:node]

          # Get the range including leading comments of first node
          start_pos = first_node.loc.expression.begin_pos
          leading_comment = leading_comment_for(first_node)
          start_pos = leading_comment.loc.expression.begin_pos if leading_comment

          # Find the beginning of the line for proper replacement
          start_pos = beginning_of_line(start_pos)
          end_pos = end_of_line(last_node.loc.expression.end_pos)

          range = range_between(start_pos, end_pos)
          corrector.replace(range, grouped_source)
        end

        def source_with_leading_comment(node)
          comment = leading_comment_for(node)
          indent = " " * node.loc.column

          if comment
            "#{indent}#{comment.text}\n#{indent}#{node.source}"
          else
            "#{indent}#{node.source}"
          end
        end

        def leading_comment_for(node)
          processed_source.comments.find do |comment|
            comment.loc.line == node.loc.line - 1
          end
        end

        def build_grouped_source(sorted_sources)
          result = []
          current_type = nil

          sorted_sources.each do |item|
            # Add blank line when switching to a new DSL type
            result << "" if current_type && current_type != item[:method]
            current_type = item[:method]
            result << item[:source]
          end

          result.join("\n")
        end

        def beginning_of_line(pos)
          source = processed_source.buffer.source
          pos -= 1 while pos > 0 && source[pos - 1] != "\n"
          pos
        end

        def end_of_line(pos)
          source = processed_source.buffer.source
          pos += 1 while pos < source.length && source[pos] != "\n"
          pos
        end

        def range_between(start_pos, end_pos)
          Parser::Source::Range.new(processed_source.buffer, start_pos, end_pos)
        end
      end
    end
  end
end
