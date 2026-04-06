# frozen_string_literal: true

require "rubocop"

# Inject default configuration
default_config = File.expand_path("../../config/default.yml", __dir__)
RuboCop::ConfigLoader.inject_defaults!(default_config)

require_relative "rubocop/cop/operandi/argument_type_required"
require_relative "rubocop/cop/operandi/condition_method_exists"
require_relative "rubocop/cop/operandi/deprecated_accessors"
require_relative "rubocop/cop/operandi/deprecated_methods"
require_relative "rubocop/cop/operandi/dsl_order"
require_relative "rubocop/cop/operandi/no_hash_argument"
require_relative "rubocop/cop/operandi/missing_private_keyword"
require_relative "rubocop/cop/operandi/no_direct_instantiation"
require_relative "rubocop/cop/operandi/output_type_required"
require_relative "rubocop/cop/operandi/prefer_optional_over_default_nil"
require_relative "rubocop/cop/operandi/prefer_fail_method"
require_relative "rubocop/cop/operandi/redundant_optional"
require_relative "rubocop/cop/operandi/reserved_name"
require_relative "rubocop/cop/operandi/step_method_exists"
