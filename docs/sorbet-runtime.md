# Sorbet Runtime Types

Operandi supports [Sorbet runtime types](https://sorbet.org/docs/runtime) for type validation of arguments and outputs. This provides runtime type checking using Sorbet's type system.

{% hint style="info" %}
This page covers **runtime type checking** with `sorbet-runtime`. For **static type analysis** with Sorbet and RBI file generation, see [Tapioca / Sorbet Integration](tapioca.md).
{% endhint %}

## Installation

Add `sorbet-runtime` to your Gemfile:

```ruby
gem "sorbet-runtime"
```

Then run:

```bash
bundle install
```

## Basic Usage

When `sorbet-runtime` is loaded, plain Ruby classes are automatically validated using Sorbet's type system:

```ruby
require "sorbet-runtime"

class User::Create < ApplicationService
  # Basic types - plain Ruby classes work directly!
  arg :name, type: String
  arg :age, type: Integer
  
  # Nilable types (allows nil)
  arg :email, type: T.nilable(String), optional: true
  
  # Union types (multiple allowed types)
  arg :status, type: T.any(String, Symbol), default: "pending"
  
  # Typed arrays
  arg :tags, type: T::Array[String], optional: true
  
  # Boolean type
  arg :active, type: T::Boolean, default: true

  # Outputs with Sorbet types - plain classes work here too
  output :user, type: User
  output :metadata, type: Hash
  
  step :create_user
  step :build_metadata

  private

  def create_user
    self.user = User.create!(
      name: name,
      age: age,
      email: email,
      status: status,
      tags: tags || [],
      active: active
    )
  end

  def build_metadata
    self.metadata = { created_at: Time.current }
  end
end
```

## Type Reference

### Basic Types

When `sorbet-runtime` is loaded, plain Ruby classes are automatically coerced to Sorbet types:

```ruby
arg :name, type: String
arg :count, type: Integer
arg :price, type: Float
arg :data, type: Hash
arg :items, type: Array
```

{% hint style="info" %}
You can also use `T::Utils.coerce(String)` explicitly, but it's not required - Operandi handles the coercion automatically.
{% endhint %}

### Nilable Types

Allow `nil` values with `T.nilable`:

```ruby
arg :nickname, type: T.nilable(String), optional: true
```

### Union Types

Allow multiple types with `T.any`:

```ruby
arg :identifier, type: T.any(String, Integer)
arg :status, type: T.any(String, Symbol)
```

### Typed Arrays

Validate array element types with `T::Array`:

```ruby
arg :tags, type: T::Array[String]
arg :numbers, type: T::Array[Integer]
arg :users, type: T::Array[User]
```

{% hint style="info" %}
**Generic Type Erasure:** Sorbet's `T::Array[String]` only validates that the value is an `Array` at runtime. The type parameter (`String`) is **erased** and not checked at runtime. For strict element validation, implement custom validation in your service steps.
{% endhint %}

### Boolean Type

Use `T::Boolean` for true/false values:

```ruby
arg :active, type: T::Boolean
arg :verified, type: T::Boolean, default: false
```

### Complex Types

Combine types for more complex validations:

```ruby
# Nilable array
arg :tags, type: T.nilable(T::Array[String]), optional: true

# Array of union types
arg :identifiers, type: T::Array[T.any(String, Integer)]
```

## Important: Sorbet Types Validate Only

{% hint style="warning" %}
**Sorbet types do NOT coerce values.** Sorbet runtime types only validate that values match the expected type. They will not automatically convert values (e.g., `"123"` will not become `123`).
{% endhint %}

### Validation Behavior

```ruby
# Sorbet runtime type
arg :age, type: Integer

# Valid - passes validation
service = MyService.run(age: 25)
service.age # => 25 (Integer)

# Invalid - raises error
service = MyService.run(age: "25")
# => Raises ArgTypeError: expected Integer, got String
```

If you need coercion, handle it explicitly in your service:

```ruby
class MyService < ApplicationService
  arg :age, type: Integer

  step :coerce_inputs
  step :process

  private

  def coerce_inputs
    self.age = age.to_i if age.is_a?(String)
  end
end
```

## Combining with Tapioca

For full Sorbet support, you can use both:

1. **Runtime types** (`sorbet-runtime`) - Validates types at runtime
2. **Static types** (Tapioca) - Generates RBI files for static analysis

See [Tapioca / Sorbet Integration](tapioca.md) for setting up static type analysis.

```ruby
# typed: strict

class User::Create < ApplicationService
  # Runtime validation with Sorbet types
  arg :name, type: String
  arg :age, type: Integer
  
  output :user, type: User
  
  # ...
end
```

With Tapioca configured, you get:
- **Runtime validation** from `sorbet-runtime`
- **IDE autocompletion** from generated RBI files
- **Static type checking** from `srb tc`

## Error Messages

When type validation fails, Operandi raises `ArgTypeError` with a descriptive message
and the associated service class:

```ruby
begin
  User::Create.run(name: 123, age: 25)
rescue Operandi::ArgTypeError => error
  error.service_class # => User::Create
  error.message
  # => "User::Create argument `name` expected String, but got Integer with value: 123"
end
```

## Full Example

```ruby
require "sorbet-runtime"

class Order::Create < ApplicationService
  # Required arguments - plain classes work!
  arg :customer, type: Customer
  arg :items, type: T::Array[OrderItem]
  arg :total, type: T.any(Integer, Float)
  
  # Optional arguments
  arg :notes, type: T.nilable(String), optional: true
  arg :priority, type: T::Boolean, default: false
  arg :tags, type: T::Array[String], optional: true
  
  # Outputs
  output :order, type: Order
  output :confirmation_number, type: String
  
  step :validate_items
  step :create_order
  step :generate_confirmation

  private

  def validate_items
    fail!("Order must have at least one item") if items.empty?
  end

  def create_order
    self.order = Order.create!(
      customer: customer,
      items: items,
      total: total,
      notes: notes,
      priority: priority,
      tags: tags || []
    )
  end

  def generate_confirmation
    self.confirmation_number = "ORD-#{order.id}-#{SecureRandom.hex(4).upcase}"
  end
end

# Usage
result = Order::Create.run(
  customer: current_user,
  items: [item1, item2],
  total: 99.99,
  priority: true
)

if result.success?
  puts "Order created: #{result.confirmation_number}"
else
  puts "Failed: #{result.errors.full_messages}"
end
```
