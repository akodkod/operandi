# frozen_string_literal: true

require "data/db"

require "data/models/application_record"
require "data/models/user"
require "data/models/product"
require "data/models/order"
require "data/models/order_item"

require "data/services/application_service"
require "data/services/create_service"
require "data/services/update_service"
require "data/services/with_class_config"
require "data/services/with_conditions"
require "data/services/with_nil_as_default"
require "data/services/with_done"
require "data/services/with_done_bypasses_always"
require "data/services/with_exception"
require "data/services/with_multiple_types"
require "data/services/with_typed_outputs"
require "data/services/with_step_insertion"
require "data/services/with_redefinition"
require "data/services/with_callbacks"
# NOTE: with_sorbet_types is loaded separately in the sorbet_types_spec to avoid
# loading sorbet-runtime globally, which would cause tapioca tests to fail
require "data/services/send_notification"

require "data/services/user/create"
require "data/services/user/update"
require "data/services/product/create"
require "data/services/order/create"
require "data/services/order/update"
require "data/services/order/recalculate"
require "data/services/order/add_product"
require "data/services/product/add_to_cart"
