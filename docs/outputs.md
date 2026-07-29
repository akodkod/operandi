# Outputs

Outputs are the results of a service.

## TL;DR

- Define outputs using the `output` keyword in the service class
- Outputs can have default values
- Outputs can be validated by type (validated when the service succeeds)

## Define Outputs

You define outputs using the `output` keyword in the service class.

```ruby
class AI::Chat < ApplicationService
  output :messages
  output :cost
end
```

## Write Outputs

Outputs function similarly to instance variables created with `attr_accessor`.

```ruby
class AI::Chat < ApplicationService
  # Steps
  step :chat

  # Outputs
  output :messages
  output :cost

  private

  def chat
    self.messages = ["Hello!", "Hi, how are you?"]
    self.cost = 0.0013
  end
end
```

To set outputs programmatically, use the `output.set` method or hash syntax.

```ruby
class AI::Chat < ApplicationService
  # ...

  def chat
    output.set(:messages, ["Hello!", "Hi, how are you?"])
    output.set(:cost, 0.0013)

    # Or use hash syntax

    output[:messages] = ["Hello!", "Hi, how are you?"]
    output[:cost] = 0.0013
  end
end
```

## Type Validation

You can specify the type of output using the `type` option. The output type will be validated when the service successfully completes.

```ruby
class AI::Chat < ApplicationService
  output :messages, type: Array
  output :cost, type: Float
end
```

You can specify multiple allowed types using an array.

```ruby
class AI::Chat < ApplicationService
  output :result, type: [String, Hash]
end
```

### Type Enforcement (Enabled by Default)

By default, all outputs must have a `type` option. This helps catch type-related bugs early and makes your services self-documenting.

```ruby
class MyService < ApplicationService
  output :result, type: Hash  # ✓ Valid
  output :data                # ✗ Raises MissingTypeError
end
```

To disable type enforcement for outputs in a specific service:

```ruby
class LegacyService < ApplicationService
  config require_output_type: false
  
  output :data             # Allowed when require_output_type is disabled
end
```

See the [Configuration documentation](configuration.md) for more details.

### Sorbet Runtime Types

Outputs support [Sorbet runtime types](https://sorbet.org/docs/runtime) for type validation:

```ruby
require "sorbet-runtime"

class AI::Chat < ApplicationService
  output :messages, type: T::Array[Hash]
  output :total_tokens, type: T::Utils.coerce(Integer)
  output :metadata, type: T.nilable(Hash), optional: true
end
```

See the [Sorbet Runtime Types documentation](sorbet-runtime.md) for more details.

## Default Values

Set default values for outputs using the `default` option. The default value will be automatically set before the execution of steps.

```ruby
class AI::Chat < ApplicationService
  output :cost, default: 0.0
end
```

## Removing Inherited Outputs

When inheriting from a parent service, you can remove outputs using `remove_output`:

```ruby
class BaseReportService < ApplicationService
  output :report
  output :debug_info
end

class ProductionReportService < BaseReportService
  # Don't expose debug info in production
  remove_output :debug_info
end
```

## What's Next?

Next, learn about context.

[Next: Context](context.md)
