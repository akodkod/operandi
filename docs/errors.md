# Errors

Errors are a natural part of every application. This guide explores how to handle errors within Operandi, drawing parallels to ActiveModel errors.

## Error Structure

Operandi errors follow a structure similar to ActiveModel errors. Here's a simplified example:

```ruby
{
  email: ["must be a valid email"],
  password: ["is too short", "must contain at least one number"]
}
```

## Adding Errors

To add an error to your service, use the `errors.add` method.

{% hint style="info" %}
By default, adding an error marks the service as failed, preventing subsequent steps from executing. This behavior can be customized in the configuration for individual services and errors.
{% endhint %}

```ruby
class ParsePage < ApplicationService
  # Arguments
  arg :url, type: String
  # ...

  # Steps
  step :validate
  step :parse
  # ...

  private

  def validate
    # Multiple errors can be added with the same key
    errors.add(:url, "must be a valid URL") unless url.match?(URI::DEFAULT_PARSER.make_regexp)
    errors.add(:url, "must be a secure link") unless url.start_with?("https")
  end

  # ...
end
```

## Quick Error with `fail!`

The `fail!` method is a shortcut for adding an error to the `:base` key:

```ruby
class ParsePage < ApplicationService
  def validate
    fail!("URL is required") if url.blank?
  end
end
```

This is equivalent to:

```ruby
errors.add(:base, "URL is required")
```

## Reading Errors

To check if a service has errors, you can use the `#failed?` method. You can also use methods like `errors.any?` to inspect errors.

```ruby
class ParsePage < ApplicationService
  def parse
    nodes.each do |node|
      if node.nil? || (node.respond_to?(:empty?) && node.empty?)
        errors.add(:base, "Node #{node} is blank")
      else
        parse_node(node)
      end
    end

    if failed? # or errors.any?
      puts "Not all nodes were parsed"
    end
  end
end
```

You can access errors outside the service using the `#errors` method.

```ruby
service = ParsePage.run(url: "rubygems")

if service.failed?
  puts service.errors
  puts service.errors[:url]
  puts service.errors.to_h # Returns errors as a hash
end
```

## Adding Warnings

Sometimes, you may want to add a warning instead of an error. Warnings are similar to errors but they do not mark the service as failed. By default they also do not stop execution and do not roll back the transaction (both behaviors can be configured globally or per-message).

```ruby
class ParsePage < ApplicationService
  def validate
    errors.add(:url, "must be a valid URL") unless url.match?(URI::DEFAULT_PARSER.make_regexp)
    warnings.add(:url, "should be a secure link") unless url.start_with?("https")
  end
end
```

```ruby
service = ParsePage.run(url: "http://rubygems.org")

if service.warnings.any?
  puts service.warnings
  puts service.warnings[:url]
  puts service.warnings.to_h # Returns warnings as a hash
end
```

## Copying Errors

### From ActiveRecord Models

Use `errors.copy_from` (or its alias `errors.from_record`) to copy errors from an ActiveRecord model:

```ruby
class User::Create < ApplicationService
  def create_user
    self.user = User.new(attributes)
    
    unless user.save
      errors.copy_from(user) # Copies all validation errors from the user model
    end
  end
end
```

### From Another Service

Copy errors from a child service that wasn't run in the same context:

```ruby
class Order::Process < ApplicationService
  def process_payment
    payment_service = Payment::Charge.run(amount:, card:)
    
    if payment_service.failed?
      errors.copy_from(payment_service)
    end
  end
end
```

## Converting Errors to Hash

Use `errors.to_h` to get a hash representation of all errors:

```ruby
service = User::Create.run(email: "invalid")

if service.failed?
  service.errors.to_h
  # => { email: ["is invalid"], password: ["can't be blank"] }
end
```

## Per-Message Options

When adding errors, you can control behavior on a per-message basis:

### Control Break Behavior

```ruby
def validate
  # This error won't stop subsequent steps from running
  errors.add(:warning_field, "has a minor issue", break: false)
  
  # This error WILL stop execution (default behavior)
  errors.add(:critical_field, "is completely invalid")
end
```

### Control Rollback Behavior

```ruby
def process
  # This error won't trigger a transaction rollback
  errors.add(:notification, "failed to send", rollback: false)
  
  # This error WILL rollback (default behavior when use_transactions is true)
  errors.add(:payment, "failed to process")
end
```

## Checking for Errors and Warnings

Operandi provides convenient methods to check error/warning states:

```ruby
service = MyService.run(args)

# Check if service has any errors
service.failed?   # => true/false
service.success?  # => true/false (opposite of failed?)
service.errors?   # => true/false (same as errors.any?)

# Check if service has any warnings
service.warnings? # => true/false (same as warnings.any?)
```

By following these guidelines, you can effectively manage errors and warnings in Operandi, ensuring a smoother and more robust application experience.

## Exception Classes

Operandi defines several exception classes for different error scenarios:

| Exception | Description |
|-----------|-------------|
| `Operandi::Error` | Base exception class for all Operandi errors |
| `Operandi::RuntimeError` | Raised while a service is running; exposes the service instance through `service` |
| `Operandi::ArgTypeError` | Raised when type validation fails; exposes the associated service class through `service_class` |
| `Operandi::ReservedNameError` | Raised when using a reserved name for arguments, outputs, or steps |
| `Operandi::InvalidNameError` | Raised when using an invalid name format |
| `Operandi::NoStepsError` | Raised when a service has no steps defined and no `run` method |
| `Operandi::MissingTypeError` | Raised when defining an argument or output without a `type` option when `require_arg_type` or `require_output_type` is enabled |
| `Operandi::StopExecution` | Control flow exception raised by `stop_immediately!` to halt execution without rollback |
| `Operandi::FailExecution` | Control flow exception raised by `fail_immediately!` to halt execution and rollback transactions |

### RuntimeError

Runtime failures caused by service errors, warnings, or invalid step execution raise
`Operandi::RuntimeError`. The exception inherits from `Operandi::Error` and provides
the concrete service instance that failed:

```ruby
begin
  MyService.run!(name: "John")
rescue Operandi::RuntimeError => error
  error.service # => the MyService instance
end
```

Errors raised while defining a service continue to use `Operandi::Error`.

### ArgTypeError

Argument and output type failures raise `Operandi::ArgTypeError`. It inherits from
`Operandi::Error` and identifies the associated service class without requiring a
service instance:

```ruby
begin
  MyService.run(name: 123)
rescue Operandi::ArgTypeError => error
  error.service_class # => MyService
end
```

### MissingTypeError

This exception is raised when you define an argument or output without a `type` option. Since `require_arg_type` and `require_output_type` are enabled by default, all arguments and outputs must have a type.

```ruby
class MyService < ApplicationService
  arg :name  # => raises Operandi::MissingTypeError
end
```

To fix this, add a `type` option to all arguments and outputs:

```ruby
class MyService < ApplicationService
  arg :name, type: String
  output :result, type: Hash
end
```

If you need to disable type enforcement for legacy services, you can use the `config` method:

```ruby
class LegacyService < ApplicationService
  config require_arg_type: false, require_output_type: false
  
  arg :data              # Allowed when require_arg_type is disabled
  output :result         # Allowed when require_output_type is disabled
end
```

### NoStepsError

This exception is raised when you attempt to execute a service that has no steps defined and no `run` method as a fallback:

```ruby
class EmptyService < ApplicationService
  # No steps defined and no run method
end

EmptyService.run # => raises Operandi::NoStepsError
```

To fix this, either define at least one step or implement a `run` method:

```ruby
# Option 1: Define steps
class MyService < ApplicationService
  step :do_work

  private

  def do_work
    # ...
  end
end

# Option 2: Use run method
class MyService < ApplicationService
  private

  def run
    # ...
  end
end
```

## What's next?

Learn about callbacks to add logging, benchmarking, and other cross-cutting concerns to your services.

[Next: Callbacks](callbacks.md)
