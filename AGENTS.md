# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## About Operandi

Operandi is a Ruby gem providing a service architecture pattern for organizing business logic. Services are defined as classes with `arguments`, `steps`, and `outputs`, featuring transactions, inheritance, error handling, and context sharing.

## Development Commands

### Testing
```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/path/to/file_spec.rb

# Run with coverage (uses SimpleCov)
bundle exec rspec
```

### Linting
```bash
# Run RuboCop linter
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -a
```

### Build and Release
```bash
# Build gem
bundle exec rake build

# Default task (runs tests)
bundle exec rake
```

## Architecture

### Core Components

1. **Base Service (`lib/operandi/base.rb:15`)**
   - Main service class that all services inherit from
   - Handles service lifecycle: initialization, execution, callbacks, error management
   - Provides DSL for defining arguments, steps, and outputs
   - Manages transactions and error propagation to parent services

2. **Callbacks System (`lib/operandi/callbacks.rb:5`)**
   - Supports service and step-level callbacks
   - Events: `before_service_run`, `after_service_run`, `around_service_run`, `on_service_success`, `on_service_failure`
   - Step events: `before_step_run`, `after_step_run`, `around_step_run`, `on_step_success`, `on_step_failure`

3. **Settings**
   - **Step (`lib/operandi/settings/step.rb:7`)**: Handles step execution with conditional logic (`if`, `unless`, `always`)
   - **Field (`lib/operandi/settings/field.rb`)**: Manages argument and output validation and type checking

4. **Messages System (`lib/operandi/messages.rb`)**
   - Collects errors and warnings with options for breaking, raising, or rolling back
   - Supports copying messages between parent and child services

5. **Collection (`lib/operandi/collection.rb`)**
   - Manages arguments and outputs as collections with validation and defaults
   - Supports Sorbet runtime types for type validation

### Service DSL

Services use a declarative DSL:
```ruby
class ExampleService < Operandi::Base
  # Define input arguments
  arg :name, type: String
  arg :age, type: Integer, optional: true, default: 25

  # Define execution steps
  step :validate_input
  step :process_data, if: :should_process?
  step :cleanup, always: true

  # Define outputs
  output :result, type: Hash

  private

  def validate_input
    errors.add(:name, "required") if name.nil? || name.strip.empty?
  end

  def process_data
    self.result = { name: name, age: age }
  end

  def cleanup
    # Runs regardless of errors/warnings, unless stop! was called
  end

  def should_process?
    !(name.nil? || name.strip.empty?)
  end
end
```

### Service Execution

- Services can be run with `.run(args)` or `.run!(args)` (raises on error)
- Use `.with(service_or_context)` to chain services with shared context
- Transactions automatically rollback on errors when `use_transactions: true`
- Steps run sequentially, stopping on errors unless `always: true`

### Error Handling

- Errors collected in `@errors` message collection
- Supports `break_on_error`, `raise_on_error`, `rollback_on_error` configuration
- Warnings work similarly with `@warnings` collection
- Parent services can inherit child errors/warnings based on configuration

### Testing Patterns

- Services are tested using RSpec with database transactions
- Use `DatabaseCleaner` for test isolation
- Mock database models and external dependencies
- Test both success and failure scenarios
- Validate arguments, outputs, and error conditions

## Configuration

### RuboCop Rules
- Target Ruby version: 2.7+
- Method length max: 20 lines
- Uses double quotes for strings
- Enables trailing commas for multiline structures
- Disables documentation requirements and guard clauses

### Database Support
- Optional ActiveRecord integration for transactions
- Uses SQLite3 for testing
- Database cleaner ensures test isolation