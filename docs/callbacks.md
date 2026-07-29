# Callbacks

Callbacks are hooks that allow you to run custom code at specific points during service and step execution. They're perfect for logging, benchmarking, auditing, and other cross-cutting concerns.

## TL;DR

- Define callbacks using DSL methods like `before_service_run`, `after_step_run`, etc.
- Use symbols (method names) or procs/lambdas
- Callbacks are inherited from parent classes
- Around callbacks wrap execution and must yield

```ruby
class User::Charge < ApplicationService
  before_service_run :log_start
  after_service_run :log_end
  on_service_failure :notify_admin

  around_step_run :benchmark_step

  step :authorize
  step :charge

  private

  def log_start(service)
    Rails.logger.info "Starting #{service.class.name}"
  end

  def log_end(service)
    Rails.logger.info "Finished #{service.class.name}"
  end

  def notify_admin(service)
    AdminMailer.service_failed(service).deliver_later
  end

  def benchmark_step(service, step_name)
    start = Time.current
    yield
    duration = Time.current - start
    Rails.logger.info "Step #{step_name} took #{duration}s"
  end
end
```

## Available Callbacks

### Service Callbacks

| Callback | When it runs | Arguments |
|----------|--------------|-----------|
| `before_service_run` | Before the service starts executing steps | `(service)` |
| `after_service_run` | After the service completes (success or failure) | `(service)` |
| `around_service_run` | Wraps the entire service execution | `(service, &block)` |
| `on_service_success` | After service completes without errors | `(service)` |
| `on_service_failure` | After service completes with errors | `(service)` |

### Step Callbacks

| Callback | When it runs | Arguments |
|----------|--------------|-----------|
| `before_step_run` | Before each step executes | `(service, step_name)` |
| `after_step_run` | After each step completes (success or failure) | `(service, step_name)` |
| `around_step_run` | Wraps each step execution | `(service, step_name, &block)` |
| `on_step_success` | After step completes without errors | `(service, step_name)` |
| `on_step_failure` | When step produces errors | `(service, step_name)` |
| `on_step_crash` | When step raises an exception | `(service, step_name, exception)` |

{% hint style="info" %}
Note the difference between `on_step_failure` and `on_step_crash`:
- `on_step_failure` is called when a step adds errors (similar to `on_service_failure`)
- `on_step_crash` is called when a step raises an exception

When a step crashes (raises an exception), `after_step_run` is NOT called.
{% endhint %}

## Defining Callbacks

### Using Symbols (Method Names)

The most common way to define callbacks is using symbols that reference instance methods:

```ruby
class Order::Process < ApplicationService
  before_service_run :log_start
  after_service_run :log_end

  step :validate
  step :process
  step :notify

  private

  def log_start(service)
    Rails.logger.info "Processing order started"
  end

  def log_end(service)
    Rails.logger.info "Processing order finished, success: #{service.success?}"
  end
end
```

### Using Procs/Lambdas

For simple callbacks, you can use inline procs:

```ruby
class Order::Process < ApplicationService
  before_service_run do |service|
    Rails.logger.info "Starting #{service.class.name}"
  end

  after_service_run do |service|
    Rails.logger.info "Completed with #{service.errors.count} errors"
  end

  on_step_failure do |service, step_name|
    Rails.logger.warn "Step #{step_name} produced errors"
  end

  on_step_crash do |service, step_name, exception|
    Bugsnag.notify(exception, step: step_name)
  end

  step :validate
  step :process
end
```

## Around Callbacks

Around callbacks wrap execution and must call `yield` to continue:

```ruby
class Order::Process < ApplicationService
  around_service_run :with_logging
  around_step_run :with_timing

  step :validate
  step :process

  private

  def with_logging(service)
    Rails.logger.info "=== Starting #{service.class.name} ==="
    yield
    Rails.logger.info "=== Finished #{service.class.name} ==="
  end

  def with_timing(service, step_name)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    Rails.logger.info "Step :#{step_name} completed in #{duration.round(3)}s"
  end
end
```

### Around Callbacks with Procs

When using procs for around callbacks, the block is passed as the last argument:

```ruby
class Order::Process < ApplicationService
  around_service_run do |service, block|
    Rails.logger.info "Starting..."
    block.call
    Rails.logger.info "Finished!"
  end

  around_step_run do |service, step_name, block|
    Rails.logger.info "Running step :#{step_name}"
    block.call
    Rails.logger.info "Completed step :#{step_name}"
  end

  step :process
end
```

{% hint style="warning" %}
Forgetting to call `yield` (or `block.call` for procs) in around callbacks will prevent the service/step from executing!
{% endhint %}

## Multiple Callbacks

You can define multiple callbacks of the same type. They execute in the order they're defined:

```ruby
class Order::Process < ApplicationService
  before_service_run :log_start
  before_service_run :validate_environment
  before_service_run :check_permissions

  step :process

  private

  def log_start(service)
    # Runs first
  end

  def validate_environment(service)
    # Runs second
  end

  def check_permissions(service)
    # Runs third
  end
end
```

### Multiple Around Callbacks

Multiple around callbacks are nested, with the first one wrapping the second:

```ruby
class Order::Process < ApplicationService
  around_service_run :outer_wrapper
  around_service_run :inner_wrapper

  step :process

  private

  def outer_wrapper(service)
    puts "outer before"
    yield
    puts "outer after"
  end

  def inner_wrapper(service)
    puts "inner before"
    yield
    puts "inner after"
  end

  # Output:
  # outer before
  # inner before
  # (service executes)
  # inner after
  # outer after
end
```

## Callback Inheritance

Callbacks are inherited from parent classes. Child class callbacks run after parent callbacks:

```ruby
class ApplicationService < Operandi::Base
  before_service_run :log_service_start

  private

  def log_service_start(service)
    Rails.logger.info "[#{service.class.name}] Starting"
  end
end

class Order::Process < ApplicationService
  before_service_run :validate_order

  step :process

  private

  def validate_order(service)
    # Runs after log_service_start
  end
end
```

### Deep Inheritance

Callbacks accumulate through the inheritance chain:

```ruby
class BaseService < Operandi::Base
  before_service_run :base_callback
end

class MiddleService < BaseService
  before_service_run :middle_callback
end

class ConcreteService < MiddleService
  before_service_run :concrete_callback

  # Execution order:
  # 1. base_callback
  # 2. middle_callback
  # 3. concrete_callback
end
```

## Execution Order

### Service Callbacks Order

```
before_service_run
  └── around_service_run (before yield)
        └── [steps execute]
      around_service_run (after yield)
after_service_run
on_service_success OR on_service_failure
```

### Step Callbacks Order (for each step)

**Normal execution (no exception):**
```
before_step_run
  └── around_step_run (before yield)
        └── [step executes]
      around_step_run (after yield)
after_step_run
on_step_success OR on_step_failure (if errors were added)
```

**Exception during step:**
```
before_step_run
  └── around_step_run (before yield)
        └── [step raises exception]
on_step_crash
[exception propagates]
```

## Use Cases

### Logging

```ruby
class ApplicationService < Operandi::Base
  before_service_run :log_start
  after_service_run :log_finish

  private

  def log_start(service)
    Rails.logger.tagged(service.class.name) do
      Rails.logger.info "Started with arguments: #{service.arg.to_h}"
    end
  end

  def log_finish(service)
    Rails.logger.tagged(service.class.name) do
      if service.success?
        Rails.logger.info "Completed successfully"
      else
        Rails.logger.warn "Failed with errors: #{service.errors.full_messages}"
      end
    end
  end
end
```

### Benchmarking

```ruby
class ApplicationService < Operandi::Base
  around_service_run :benchmark

  private

  def benchmark(service)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

    if duration > 1.0
      Rails.logger.warn "#{service.class.name} took #{duration.round(2)}s"
    end
  end
end
```

### Error Tracking

```ruby
class ApplicationService < Operandi::Base
  on_service_failure :track_failure
  on_step_failure :track_step_error
  on_step_crash :track_step_crash

  private

  def track_failure(service)
    Bugsnag.notify("Service failed") do |report|
      report.add_metadata(:service, {
        class: service.class.name,
        errors: service.errors.full_messages,
        arguments: service.arg.to_h
      })
    end
  end

  def track_step_error(service, step_name)
    Rails.logger.warn "Step :#{step_name} produced errors in #{service.class.name}"
  end

  def track_step_crash(service, step_name, exception)
    Bugsnag.notify(exception) do |report|
      report.add_metadata(:service, {
        class: service.class.name,
        step: step_name
      })
    end
  end
end
```

### Audit Trail

```ruby
class Order::Process < ApplicationService
  after_service_run :create_audit_log

  arg :order, type: Order
  arg :current_user, type: User

  step :process

  private

  def create_audit_log(service)
    AuditLog.create!(
      user: current_user,
      action: "order.process",
      resource: order,
      success: service.success?,
      metadata: {
        errors: service.errors.full_messages
      }
    )
  end
end
```

### Database Instrumentation

```ruby
class ApplicationService < Operandi::Base
  around_step_run :track_queries

  private

  def track_queries(service, step_name)
    query_count = 0
    
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do
      query_count += 1
    end

    yield

    ActiveSupport::Notifications.unsubscribe(subscriber)
    
    if query_count > 10
      Rails.logger.warn "Step :#{step_name} executed #{query_count} queries"
    end
  end
end
```

## What's Next?

Learn about testing your services, including how to test callbacks.

[Next: Testing](testing.md)

