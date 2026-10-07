# frozen_string_literal: true

module RuboCop
  module Cop
    module Operandi
      # Requires section comments above DSL groups in service classes.
      #
      # The expected comments, in order, are `# Arguments`, `# Steps`, and `# Outputs`.
      # Section comments are optional for a single DSL declaration in a class.
      # `config` is not a section.
      #
      # @safety
      #   Autocorrection inserts or replaces section comments and does not move code.
      #
      # @example
      #   # bad
      #   class MyService < ApplicationService
      #     arg :user, type: User
      #     step :process
      #     output :result, type: Hash
      #   end
      #
      #   # good
      #   class MyService < ApplicationService
      #     # Arguments
      #     arg :user, type: User
      #
      #     # Steps
      #     step :process
      #
      #     # Outputs
      #     output :result, type: Hash
      #   end
      #
      class SectionComments < Base
        extend AutoCorrector
        include RangeHelp

        MSG_MISSING = "Add a `# %<title>s` section comment before `%<method>s` declarations."
        MSG_WRONG = "Section comment must be `# %<title>s`."
        MSG_ORDER = "`# %<title>s` section must come before `# %<previous>s`. " \
                    "Expected order: Arguments → Steps → Outputs."

        SECTIONS = {
          arg: "Arguments",
          step: "Steps",
          output: "Outputs",
        }.freeze
        ORDER = [:arg, :step, :output].freeze

        def on_class(node)
          groups = section_groups(class_body_statements(node))
          return if groups.empty?

          check_groups(groups)
        end

        private

        def class_body_statements(node)
          body = node.body
          return [] unless body

          body.begin_type? ? body.children : [body]
        end

        def section_groups(statements)
          statements.each_with_object([]) do |statement, groups|
            next unless dsl_call?(statement)

            append_section_call(groups, statement)
          end
        end

        def append_section_call(groups, statement)
          if groups.last && groups.last[:method] == statement.method_name
            groups.last[:nodes] << statement
          else
            groups << { method: statement.method_name, nodes: [statement] }
          end
        end

        def dsl_call?(node)
          node.send_type? && node.receiver.nil? && SECTIONS.key?(node.method_name)
        end

        def check_groups(groups)
          highest = -1
          required = groups.sum { |group| group[:nodes].size } > 1

          groups.each do |group|
            highest = check_group_order(group, highest)
            check_comment(group, required: required)
          end
        end

        def check_group_order(group, highest)
          index = ORDER.index(group[:method])
          return register_order_offense(group, highest) if index < highest

          index
        end

        def register_order_offense(group, highest)
          node = group[:nodes].first
          # A missing heading is also reported on the declaration, so highlight the
          # selector here and leave the full declaration for that offense.
          range = section_comment(node) ? node : node.loc.selector
          add_offense(range, message: order_message(group[:method], highest))
          highest
        end

        def order_message(method_name, highest)
          format(MSG_ORDER, title: SECTIONS[method_name], previous: SECTIONS[ORDER[highest]])
        end

        def check_comment(group, required:)
          node = group[:nodes].first
          title = SECTIONS[group[:method]]
          comment = section_comment(node)

          if comment.nil?
            register_missing(node, title, group[:method]) if required
          elsif !correct_comment?(comment, node, title)
            register_wrong(comment, node, title)
          end
        end

        def register_missing(node, title, method_name)
          message = format(MSG_MISSING, title: title, method: method_name)
          add_offense(node, message: message) do |corrector|
            insert_comment(corrector, node, title)
          end
        end

        def register_wrong(comment, node, title)
          add_offense(comment.loc.expression, message: format(MSG_WRONG, title: title)) do |corrector|
            replace_comment(corrector, comment, node, title)
          end
        end

        def section_comment(node)
          line = node.loc.line - 1
          while (comment = processed_source.comment_at_line(line)) && full_line_comment?(comment)
            return comment if comment.text.match?(/\A#\s*(?:Arguments?|Args?|Steps?|Outputs?)\s*:?\s*\z/i)

            line -= 1
          end
          nil
        end

        def full_line_comment?(comment)
          processed_source.lines[comment.loc.line - 1].strip == comment.text
        end

        def correct_comment?(comment, node, title)
          comment.text == "# #{title}" && comment.loc.expression.column == node.loc.column
        end

        def insert_comment(corrector, node, title)
          indent = " " * node.loc.column
          corrector.insert_before(node, "# #{title}\n#{indent}")
        end

        def replace_comment(corrector, comment, node, title)
          indent = " " * node.loc.column
          corrector.replace(comment_range(comment), "#{indent}# #{title}")
        end

        def comment_range(comment)
          expression = comment.loc.expression
          range_between(expression.begin_pos - expression.column, expression.end_pos)
        end
      end
    end
  end
end
