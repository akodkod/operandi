# Arguments

Arguments are the inputs to a service. They are passed to the service when it is invoked.

## TL;DR

- Define arguments with the `arg` keyword in the service class
- Validate arguments by type
- Specify arguments as required or optional
- Set default values for arguments
- Access arguments like instance variables
- Use predicate methods for arguments

```ruby
class User::Charge < ApplicationService
  arg :user, type: User
  arg :amount, type: Float
  arg :send_receipt, type: [TrueClass, FalseClass], default: true
  # In Rails you might prefer `Date.current`.
  arg :invoice_date, type: Date, default: -> { Date.today }

  step :send_email_receipt, if: :send_receipt?

  # ...
end
```

## Define Arguments

Arguments are defined using the `arg` keyword in the service class.

```ruby
class HappyBirthdayService < ApplicationService
  arg :name
  arg :age
end
```

## Type Validation

Arguments can be validated by type.

```ruby
class HappyBirthdayService < ApplicationService
  arg :name, type: String
  arg :age, type: Integer
end
```

You can specify multiple allowed types using an array.

```ruby
class HappyBirthdayService < ApplicationService
  arg :name, type: [String, Symbol]
end
```

### Type Enforcement (Enabled by Default)

By default, all arguments must have a `type` option. This helps catch type-related bugs early and makes your services self-documenting.

```ruby
class MyService < ApplicationService
  arg :name, type: String  # ✓ Valid
  arg :age                 # ✗ Raises MissingTypeError
end
```

To disable type enforcement for arguments in a specific service:

```ruby
class LegacyService < ApplicationService
  config require_arg_type: false
  
  arg :name              # Allowed when require_arg_type is disabled
end
```

See the [Configuration documentation](configuration.md) for more details.

### Sorbet Runtime Types

Operandi supports [Sorbet runtime types](https://sorbet.org/docs/runtime) for type validation. Sorbet types **only validate** and do not coerce values.

```ruby
require "sorbet-runtime"

class User::Create < ApplicationService
  # Basic types using T::Utils.coerce
  arg :name, type: T::Utils.coerce(String)
  arg :age, type: T::Utils.coerce(Integer)
  
  # Nilable types
  arg :email, type: T.nilable(String), optional: true
  
  # Union types
  arg :status, type: T.any(String, Symbol)
  
  # Typed arrays
  arg :tags, type: T::Array[String]
  
  # Boolean type
  arg :active, type: T::Boolean, default: true
end
```

{% hint style="warning" %}
**Sorbet types do NOT coerce values.** If you pass `"25"` where an `Integer` is expected, it will raise an error instead of converting the string to an integer.
{% endhint %}

See the [Sorbet Runtime Types documentation](sorbet-runtime.md) for more details.

## Required Arguments

By default, arguments are required. You can make them optional by setting `optional` to `true`.

```ruby
class HappyBirthdayService < ApplicationService
  arg :name, type: String
  arg :age, type: Integer, optional: true
end
```

## Default Values

Set a default value for an argument to make it optional.

```ruby
class HappyBirthdayService < ApplicationService
  arg :name, type: String
  arg :age, type: Integer, default: 18
end
```

### Complex Default Values

Default values are deep duplicated when the service is invoked, making it safe to use mutable objects.

```ruby
arg :options, type: Hash, default: { a: 1, b: 2 }
```

### Procs as Default Values

Use procs for dynamic default values.

```ruby
arg :current_date, type: Date, default: -> { Date.current }
```

## Inheritance

Arguments are inherited from parent classes.

```ruby
# UpdateRecordService
class UpdateRecordService < ApplicationService
  # Arguments
  arg :record, type: ApplicationRecord
  arg :attributes, type: Hash

  # Steps
  step :authorize
  step :update_record
end
```

```ruby
# User::Update inherited from UpdateRecordService
class User::Update < UpdateRecordService
  # Nothing to do here
  # Arguments and steps are inherited from UpdateRecordService
end
```

### Removing Inherited Arguments

To remove an inherited argument, use `remove_arg`:

```ruby
class BaseService < ApplicationService
  arg :current_user, type: User
  arg :audit_log, type: [TrueClass, FalseClass], default: true
end

class SystemTaskService < BaseService
  # System tasks don't need a current_user
  remove_arg :current_user
end
```

## Context Arguments

Context arguments are automatically passed to all child services in the same context. Define them using the `context` option. This is useful for passing objects like `current_user`.

Learn more about context in the [Context documentation](context.md).

```ruby
class ApplicationService < Operandi::Base
  arg :current_user, type: User, optional: true, context: true
end
```

## Accessing Arguments

Arguments are accessible like instance variables, similar to `attr_accessor`.

```ruby
class HappyBirthdayService < ApplicationService
  # Arguments
  arg :name, type: String
  arg :age, type: Integer

  # Steps
  step :greet

  private

  def greet
    puts "Happy birthday, #{name}! You are #{age} years old."
  end
end
```

## Accessing Arguments Using `arg`

For dynamic access or to avoid conflicts, use the `arg` method.

```ruby
class HappyBirthdayService < ApplicationService
  # Arguments
  arg :name, type: String
  arg :age, type: Integer

  # Steps
  step :greet

  private

  def greet
    name = arg[:name] # or arg.get(:name)
    age = arg[:age] # or arg.get(:age)

    puts "Happy birthday, #{name}! You are #{age} years old."
  end
end
```

## Argument Predicate Methods

Predicate methods are automatically generated for each argument, allowing you to check if an argument is `true` or `false`.

```ruby
class User::GenerateInvoice < ApplicationService
  # Arguments
  arg :user, type: User
  arg :charge, type: [TrueClass, FalseClass], default: false

  # Steps
  step :generate_invoice
  step :charge_user, if: :charge?

  # ...
end
```

{% hint style="info" %}
The predicate methods return `true` or `false` based on Ruby's convention: `nil` and `false` are `false`, everything else is `true`.
{% endhint %}

## What's Next?

Next step is `steps` (I love this pun). Steps are the building blocks of a service, the methods that do the actual work.

[Next: Steps](steps.md)
