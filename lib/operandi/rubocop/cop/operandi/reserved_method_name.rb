# frozen_string_literal: true

require_relative "../../../../operandi/constants"

module RuboCop
  module Cop
    module Operandi
      # Prevents service instance methods from replacing Operandi's lifecycle and state.
      # Use `run` for a single-action service, or declare named steps instead.
      # Class methods and methods in unrelated classes are not checked.
      #
      # @example
      #   # bad
      #   class FetchTickets < Operandi::Base
      #     def call; end
      #   end
      #
      #   # good
      #   class FetchTickets < Operandi::Base
      #     def run; end
      #   end
      class ReservedMethodName < Base
        MSG = "`%<name>s` is reserved for Operandi internals. Use `run` or a named step instead."

        RESERVED_METHODS = ::Operandi::ReservedNames::BASE_METHODS

        def on_def(node)
          return unless RESERVED_METHODS.include?(node.method_name)

          scope = node.each_ancestor(:class, :module, :sclass, :def, :defs).first
          return unless scope&.class_type? && service_class?(scope)

          add_offense(node.loc.name, message: format(MSG, name: node.method_name))
        end

        private

        def service_class?(node, visited = [])
          parent = node.parent_class
          return false unless parent&.const_type?

          superclass_names(parent, node).each do |name|
            return true if service_base_classes.include?(name)

            local_parent = processed_source.ast.each_node(:class).find { |candidate| qualified_name(candidate) == name }
            next unless local_parent
            return false if visited.include?(name)

            return service_class?(local_parent, visited + [name])
          end
          false
        end

        def service_base_classes
          cop_config.fetch("ServiceBaseClasses", ["Operandi::Base", "ApplicationService"])
        end

        def superclass_names(parent, node)
          name = parent.const_name
          return [name.delete_prefix("::")] if parent.source.start_with?("::")

          namespaces = node.each_ancestor(:class, :module).map { |scope| qualified_name(scope) }
          namespaces.map { |namespace| "#{namespace}::#{name}" } + [name]
        end

        def qualified_name(node)
          name = node.identifier.const_name
          return name.delete_prefix("::") if node.identifier.source.start_with?("::")

          scope = node.each_ancestor(:class, :module).first
          scope ? "#{qualified_name(scope)}::#{name}" : name
        end
      end
    end
  end
end
