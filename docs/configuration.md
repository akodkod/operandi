# Configuration

Operandi provides a flexible configuration system that allows you to customize behavior at three levels: global, per-service, and per-call.

## Global Configuration

Configure Operandi globally using an initializer. For Rails applications, create `config/initializers/operandi.rb`:

```ruby
Operandi.configure do |config|
  # Type enforcement
  config.require_arg_type = true        # Require type option for all arguments
  config.require_output_type = true     # Require type option for all outputs

  # Transaction settings
  config.use_transactions = true        # Wrap each service in a database transaction

  # Error behavior
  config.load_errors = true             # Copy errors to parent service in context chain
  config.break_on_error = true          # Stop step execution when an error is added
  config.raise_on_error = false         # Raise an exception when an error is added
  config.rollback_on_error = true       # Rollback transaction when an error is added

  # Warning behavior
  config.load_warnings = true           # Copy warnings to parent service in context chain
  config.break_on_warning = false       # Stop step execution when a warning is added
  config.raise_on_warning = false       # Raise an exception when a warning is added
  config.rollback_on_warning = false    # Rollback transaction when a warning is added
end
```

## Default Values

| Option | Default | Description |
|--------|---------|-------------|
| `require_arg_type` | `true` | Raises `Operandi::MissingTypeError` when defining arguments without a `type` option |
| `require_output_type` | `true` | Raises `Operandi::MissingTypeError` when defining outputs without a `type` option |
| `use_transactions` | `true` | Wraps service execution in `ActiveRecord::Base.transaction` |
| `load_errors` | `true` | Propagates errors to parent service when using `.with(self)` |
| `break_on_error` | `true` | Stops executing remaining steps when an error is added |
| `raise_on_error` | `false` | Raises `Operandi::RuntimeError` when an error is added |
| `rollback_on_error` | `true` | Rolls back the transaction when an error is added |
| `load_warnings` | `true` | Propagates warnings to parent service when using `.with(self)` |
| `break_on_warning` | `false` | Stops executing remaining steps when a warning is added |
| `raise_on_warning` | `false` | Raises `Operandi::RuntimeError` when a warning is added |
| `rollback_on_warning` | `false` | Rolls back the transaction when a warning is added |

## Per-Service Configuration

Override global configuration for a specific service class using the `config` class method:

```ruby
class CriticalPaymentService < ApplicationService
  # This service will raise exceptions instead of collecting errors
  config raise_on_error: true

  step :process_payment
  step :send_receipt

  # ...
end
```

```ruby
class NonCriticalNotificationService < ApplicationService
  # This service doesn't need transactions and shouldn't stop on errors
  config use_transactions: false, break_on_error: false

  step :send_push_notification
  step :send_email_notification

  # ...
end
```

## Per-Call Configuration

Override configuration for a single service call:

```ruby
# Pass config as second argument to run
MyService.run({ name: "John" }, { raise_on_error: true })

# Or use with() for context-based calls
MyService.with({ raise_on_error: true }).run(name: "John")

# Combine with parent service context
ChildService
  .with(self, { use_transactions: false })
  .run(data: some_data)
```

## Configuration Precedence

Configuration is merged in this order (later overrides earlier):

1. Global configuration (from initializer)
2. Per-service configuration (from `config` class method)
3. Per-call configuration (from `run` or `with` arguments)

```ruby
# Global: raise_on_error = false
Operandi.configure do |config|
  config.raise_on_error = false
end

# Per-service: raise_on_error = true (overrides global)
class MyService < ApplicationService
  config raise_on_error: true
end

# Per-call: raise_on_error = false (overrides per-service)
MyService.run(args, { raise_on_error: false })
```

## Common Configuration Patterns

### Strict Mode for Critical Services

```ruby
class Payment::Process < ApplicationService
  config raise_on_error: true, rollback_on_error: true
  
  # Any error will raise an exception and rollback the transaction
end
```

### Fire-and-Forget Services

```ruby
class Analytics::Track < ApplicationService
  config use_transactions: false, break_on_error: false, load_errors: false
  
  # Errors won't stop execution or propagate to parent services
end
```

### Background Job Services

```ruby
class BackgroundTaskService < ApplicationService
  # Background jobs typically handle their own transactions
  config use_transactions: false
end
```

### Type Enforcement (Enabled by Default)

By default, all arguments and outputs must have a `type` option. This helps catch type-related bugs early and makes your services self-documenting.

```ruby
class User::Create < ApplicationService
  arg :name, type: String        # ✓ Valid
  arg :email                     # ✗ Raises MissingTypeError
  output :user, type: User       # ✓ Valid
  output :token                  # ✗ Raises MissingTypeError
end
```

To disable type enforcement globally (not recommended):

```ruby
Operandi.configure do |config|
  config.require_arg_type = false     # Disable for arguments
  config.require_output_type = false  # Disable for outputs
end
```

Or disable for specific services:

```ruby
class LegacyService < ApplicationService
  config require_arg_type: false, require_output_type: false
  
  arg :data              # Allowed when require_arg_type is disabled
  output :result         # Allowed when require_output_type is disabled
end
```

You can also control them independently:

```ruby
class StrictInputService < ApplicationService
  # Require types for arguments but not outputs
  config require_arg_type: true, require_output_type: false
  
  arg :data, type: Hash  # Type required
  output :result         # Type not required
end
```

## Disabling Transactions

If you're not using ActiveRecord or want to manage transactions yourself:

```ruby
Operandi.configure do |config|
  config.use_transactions = false
end
```

Or disable for specific services:

```ruby
class MyService < ApplicationService
  config use_transactions: false
end
```

{% hint style="info" %}
When `use_transactions` is `true`, Operandi uses `ActiveRecord::Base.transaction(requires_new: true)` to create savepoints, allowing nested services to rollback independently.
{% endhint %}

## What's Next?

Now that you understand configuration, learn about the core concepts:

[Next: Concepts](concepts.md)
