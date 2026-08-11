# 🚀 Operandi

Operandi is a simple yet powerful way to organize business logic in Ruby applications. Build services that are easy to test, maintain, and understand.

![GitHub CI](https://github.com/akodkod/operandi/actions/workflows/ci.yml/badge.svg)
[![Codecov](https://codecov.io/gh/akodkod/operandi/graph/badge.svg?token=IGJNZ2BQ26)](https://codecov.io/gh/akodkod/operandi)

[Get started with Quickstart](https://operandi.kodkod.me/quickstart)

## Features

- ✨ **Simple**: Define your service as a class with `arguments`, `steps`, and `outputs`
- 📦 **No runtime dependencies**: Works stand-alone without requiring external gems at runtime
- 🔄 **Transactions**: Automatically rollback database changes if any step fails
- 🧬 **Inheritance**: Inherit from other services to reuse logic seamlessly
- ⚠️ **Error Handling**: Collect errors from steps and handle them your way
- 🔗 **Context**: Run multiple services sequentially within the same context
- 🧪 **RSpec Matchers**: Built-in RSpec matchers for expressive service tests
- 🌐 **Framework Agnostic**: Compatible with Rails, Hanami, or any Ruby framework
- 🧩 **Modularity**: Isolate and test your services with ease
- 🔷 **Sorbet & Tapioca**: Full support for Sorbet type checking and Tapioca DSL generation
- ✅ **100% Test Coverage**: Thoroughly tested and reliable
- ⚔️ **Battle-Tested**: In production use since 2017

## Installation

Operandi requires Ruby 3.2 or later.

```ruby
gem "operandi", "~> 5.0"
```

```bash
rails generate operandi:install
```

## Simple Example

```ruby
class GreetService < Operandi::Base
  # Arguments
  arg :name, type: String
  arg :age, type: Integer

  # Steps
  step :build_message
  step :send_message

  # Outputs
  output :message, type: String

  private

  def build_message
    self.message = "Hello, #{name}! You are #{age} years old."
  end

  def send_message
    # Send logic goes here
  end
end
```

## Advanced Example (with Sorbet types and conditions)

```ruby
class User::ResetPassword < Operandi::Base
  # Arguments with Sorbet types
  arg :user, type: User, optional: true
  arg :email, type: String, optional: true
  arg :send_email, type: T::Boolean, default: true
  arg :metadata, type: T::Hash[Symbol, String], default: {}
  arg :notify_channels, type: T::Array[Symbol], default: [:email]

  # Steps
  step :validate
  step :find_user, unless: :user?
  step :generate_reset_token
  step :save_reset_token
  step :send_reset_email, if: :send_email?

  # Outputs
  output :user, type: User
  output :reset_token, type: String
  output :notifications_sent, type: T::Array[Symbol]

  private

  def validate
    errors.add(:base, "user or email is required") if !user? && !email?
  end

  def find_user
    self.user = User.find_by("LOWER(email) = ?", email.downcase)
    errors.add(:email, "not found") unless user
  end

  def generate_reset_token
    self.reset_token = SecureRandom.hex(32)
  end

  def save_reset_token
    user.update!(
      reset_password_token: reset_token,
      reset_password_sent_at: Time.current,
    )
  rescue ActiveRecord::RecordInvalid => e
    errors.from_record(e.record)
  end

  def send_reset_email
    Mailer::SendEmail
      .with(self) # Call sub-service with the same context
      .run(template: :reset_password, user:, reset_token:)
  end
end
```

[Get started with Operandi](https://operandi.kodkod.me/quickstart)

## Rails Generators

Operandi includes Rails generators to help you quickly set up and create services in your Rails application.

### Install Generator

Set up Operandi in your Rails application:

```bash
bin/rails generate operandi:install
```

This creates:
- `app/services/application_service.rb` - Base service class for your application
- `config/initializers/operandi.rb` - Configuration file
- `spec/services/application_service_spec.rb` - RSpec test file (if RSpec is detected)

**Options:**
- `--skip-initializer` - Skip creating the initializer file
- `--skip-spec` - Skip creating the spec file

### Service Generator

Create a new service class:

```bash
# Basic service
bin/rails generate operandi:service user/create

# Service with predefined structure
bin/rails generate operandi:service CreateOrder \
  --args=user product \
  --steps=validate process \
  --outputs=order
```

This creates:
- `app/services/user/create.rb` - Service class file
- `spec/services/user/create_spec.rb` - RSpec test file (if RSpec is detected)

**Options:**
- `--args` - List of arguments for the service (e.g., `--args=user product`)
- `--steps` - List of steps for the service (e.g., `--steps=validate process`)
- `--outputs` - List of outputs for the service (e.g., `--outputs=result`)
- `--skip-spec` - Skip creating the spec file
- `--parent` - Parent class (default: ApplicationService)

## Documentation

You can find the full documentation at [operandi.kodkod.me](https://operandi.kodkod.me).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
