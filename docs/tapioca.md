# Tapioca / Sorbet Integration

Operandi provides a [Tapioca](https://github.com/Shopify/tapioca) DSL compiler that generates RBI signatures for methods automatically created by the `arg` and `output` DSL macros. This enables full Sorbet type checking for your services.

## Features

When you use the `arg` or `output` keywords, Operandi dynamically generates methods at runtime:

```ruby
class CreateUser < ApplicationService
  arg :name, type: String
  arg :email, type: String, optional: true
  arg :role, type: [Symbol, String]
  
  output :user, type: User
end
```

The Tapioca compiler generates RBI signatures for these methods:

```rbi
# sorbet/rbi/dsl/create_user.rbi
# typed: true

class CreateUser
  sig { returns(String) }
  def name; end

  sig { returns(T::Boolean) }
  def name?; end

  sig { returns(T.nilable(String)) }
  def email; end

  sig { returns(T::Boolean) }
  def email?; end

  sig { returns(T.any(Symbol, String)) }
  def role; end

  sig { returns(T::Boolean) }
  def role?; end

  sig { returns(User) }
  def user; end

  sig { returns(T::Boolean) }
  def user?; end

  private

  sig { params(value: String).returns(String) }
  def name=(value); end

  sig { params(value: T.nilable(String)).returns(T.nilable(String)) }
  def email=(value); end

  sig { params(value: T.any(Symbol, String)).returns(T.any(Symbol, String)) }
  def role=(value); end

  sig { params(value: User).returns(User) }
  def user=(value); end
end
```

## Setup

### 1. Install Tapioca

Add Tapioca to your Gemfile:

```ruby
group :development do
  gem "tapioca", require: false
end
```

Then run:

```bash
bundle install
bundle exec tapioca init
```

### 2. Generate RBI Files

The Operandi compiler is automatically discovered by Tapioca. Generate RBI files with:

```bash
bundle exec tapioca dsl
```

This will create RBI files in `sorbet/rbi/dsl/` for all your services.

### 3. Re-generate After Changes

After adding or modifying `arg`/`output` declarations, regenerate the RBI files:

```bash
bundle exec tapioca dsl Operandi
```

## Type Mappings

### Ruby Types

Standard Ruby types are mapped directly:

| Ruby Type | Sorbet Type |
|-----------|-------------|
| `String` | `::String` |
| `Integer` | `::Integer` |
| `Float` | `::Float` |
| `Hash` | `::Hash` |
| `Array` | `::Array` |
| `Symbol` | `::Symbol` |
| `User` (custom) | `::User` |

### Boolean Types

Boolean types are mapped to `T::Boolean`:

```ruby
arg :active, type: [TrueClass, FalseClass]
# Generates: sig { returns(T::Boolean) }
```

### Union Types

Multiple types create union types:

```ruby
arg :id, type: [String, Integer]
# Generates: sig { returns(T.any(::String, ::Integer)) }
```

### Optional Types

Optional arguments/outputs are wrapped in `T.nilable`:

```ruby
arg :nickname, type: String, optional: true
# Generates: sig { returns(T.nilable(::String)) }
```

### Sorbet Runtime Types

Sorbet runtime types are automatically resolved:

| Sorbet Type | Generated RBI |
|-------------|---------------|
| `T::Boolean` | `T::Boolean` |
| `T.nilable(String)` | `T.nilable(::String)` |
| `T::Array[String]` | `T::Array[::String]` |
| `T::Hash[Symbol, String]` | `T::Hash[::Symbol, ::String]` |
| `T.any(String, Integer)` | `T.any(::String, ::Integer)` |

## Generated Methods

For each `arg` or `output`, three methods are generated:

| Method | Return Type | Visibility |
|--------|-------------|------------|
| `name` | The declared type | public |
| `name?` | `T::Boolean` | public |
| `name=` | The declared type | **private** |

## Inheritance

The compiler emits argument and output methods only on the service where each field is declared. Child services inherit those methods normally, while their generated `Arguments` and `Outputs` types and `.run` signatures still include inherited fields.

This preserves method overrides that narrow an inherited field's type. For example, a base service can declare an optional `current_user` argument and an authenticated subclass can override its getter to return a non-nilable `User`; descendants will inherit the narrowed return type instead of having the optional DSL signature redeclared.

## Troubleshooting

### RBI files not generated

Ensure Operandi is properly loaded in your application. The compiler only runs if `Operandi::Base` is defined.

### Types showing as `T.untyped`

This happens when:
- No `type:` option is specified for the argument/output
- The type cannot be resolved (e.g., undefined constant)

## See Also

- [Ruby LSP Integration](ruby-lsp.md) - Editor integration without Sorbet
- [Arguments](arguments.md) - Full `arg` DSL documentation  
- [Outputs](outputs.md) - Full `output` DSL documentation
