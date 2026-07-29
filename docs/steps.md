# Steps

Steps are the core components of a service, each representing a unit of work executed in sequence when the service is called.

## TL;DR

- Define steps using the `step` keyword within the service class
- Use `if` and `unless` options for conditional steps
- Inherit steps from parent classes
- Inject steps into the execution flow with `before` and `after` options
- Ensure cleanup steps run with the `always: true` option (unless `stop!` was called)
- Use a `run` method as a simple alternative for single-step services

```ruby
class GeneralParserService < ApplicationService
  step :create_browser, unless: :browser
  step :parse_content
  step :quit_browser, always: true
end

class ParsePage < GeneralParserService
  step :parse_additional_content, after: :parse_content
end
```

## Define Steps

Steps are declared using the `step` keyword in your service class.

```ruby
class User::Charge < ApplicationService
  step :authorize
  step :charge
  step :send_email_receipt

  private

  def authorize
    # ...
  end

  def charge
    # ...
  end

  def send_email_receipt
    # ...
  end
end
```

## Conditional Steps

Steps can be conditional, executed based on specified conditions using the `if` or `unless` keywords.

```ruby
class User::Charge < ApplicationService
  step :authorize
  step :charge
  step :send_email_receipt, if: :send_receipt?

  # ...

  def send_receipt?
    rand(2).zero?
  end
end
```

This feature works well with argument predicates.

```ruby
class User::Charge < ApplicationService
  arg :send_receipt, type: [TrueClass, FalseClass], default: true

  step :send_email_receipt, if: :send_receipt?

  # ...
end
```

### Using Procs for Conditions

You can also use Procs (lambdas) for inline conditions:

```ruby
class User::Charge < ApplicationService
  arg :amount, type: Float

  step :apply_discount, if: -> { amount > 100 }
  step :charge
  step :send_large_purchase_alert, if: -> { amount > 1000 }

  # ...
end
```

{% hint style="info" %}
Using Procs can make simple conditions more readable, but for complex logic, prefer extracting to a method.
{% endhint %}

## Inheritance

Steps are inherited from parent classes, making it easy to build upon existing services.

```ruby
# UpdateRecordService
class UpdateRecordService < ApplicationService
  arg :record, type: ApplicationRecord
  arg :attributes, type: Hash

  step :authorize
  step :update_record
end
```

```ruby
# User::Update inherited from UpdateRecordService
class User::Update < UpdateRecordService
  # Arguments and steps are inherited from UpdateRecordService
end
```

## Injecting Steps into Execution Flow

Steps can be injected at specific points in the execution flow using `before` and `after` options.

Let's enhance the previous example by adding a step to send a notification after updating the record.

```ruby
# User::Update inherited from UpdateRecordService
class User::Update < UpdateRecordService
  step :log_action, before: :authorize
  step :send_notification, after: :update_record

  private

  def log_action
    # ...
  end

  def send_notification
    # ...
  end
end
```

Combine this with `if` and `unless` options for more control.

```ruby
step :send_notification, after: :update_record, if: :send_notification?
```

{% hint style="info" %}
By default, if neither `before` nor `after` is specified, the step is added at the end of the execution flow.
{% endhint %}

## Always Running Steps

To ensure certain steps run regardless of previous step outcomes (errors, warnings, failed validations), use the `always: true` option. This is particularly useful for cleanup tasks, error logging, etc.

Note: if `stop!` was called, the service exits early and `always: true` steps will **not** run.

```ruby
class ParsePage < ApplicationService
  arg :url, type: String

  step :create_browser
  step :parse_content
  step :quit_browser, always: true

  private

  attr_accessor :browser

  def create_browser
    self.browser = Watir::Browser.new
  end

  def parse_content
    # ...
  end

  def quit_browser
    browser&.quit
  end
end
```

## Early Exit with `stop!`

Use `stop!` to stop executing remaining steps without adding an error. This is useful when you've completed the service's goal early and don't need to run subsequent steps.

```ruby
class User::FindOrCreate < ApplicationService
  arg :email, type: String

  step :find_existing_user
  step :create_user
  step :send_welcome_email

  output :user

  private

  def find_existing_user
    self.user = User.find_by(email:)
    stop! if user # Skip remaining steps if user already exists
  end

  def create_user
    self.user = User.create!(email:)
  end

  def send_welcome_email
    # Only runs for newly created users
    Mailer.welcome(user).deliver_later
  end
end
```

You can check if `stop!` was called using `stopped?`:

```ruby
def some_step
  stop!
  
  # This code still runs within the same step
  puts "Stopped? #{stopped?}" # => "Stopped? true"
end

def next_step
  # This step will NOT run because stop! was called
end
```

{% hint style="info" %}
`stop!` stops subsequent steps from running, including steps marked with `always: true`. Code after `stop!` within the same step method will still execute.
{% endhint %}

{% hint style="success" %}
**Database Transactions:** Calling `stop!` does NOT rollback database transactions. All database changes made before `stop!` was called will be committed.
{% endhint %}

## Immediate Exit with `stop_immediately!`

Use `stop_immediately!` when you need to halt execution immediately, even within the current step. Unlike `stop!`, code after `stop_immediately!` in the same step method will NOT execute.

```ruby
class Payment::Process < ApplicationService
  arg :amount, type: Integer
  arg :card_token, type: String

  step :validate_card
  step :charge_card
  step :send_receipt

  output :transaction_id, type: String

  private

  def validate_card
    unless valid_card?(card_token)
      errors.add(:card, "is invalid")
      stop_immediately! # Exit immediately - don't run any more code
    end
    
    # This code won't run if card is invalid
    log_validation_success
  end

  def charge_card
    # This step won't run if stop_immediately! was called
    self.transaction_id = PaymentGateway.charge(amount, card_token)
  end

  def send_receipt
    Mailer.receipt(transaction_id).deliver_later
  end
end
```

{% hint style="warning" %}
`stop_immediately!` raises an internal exception to halt execution. Steps marked with `always: true` will NOT run when `stop_immediately!` is called.
{% endhint %}

{% hint style="success" %}
**Database Transactions:** Calling `stop_immediately!` does NOT rollback database transactions. All database changes made before `stop_immediately!` was called will be committed.
{% endhint %}

## Immediate Failure with `fail_immediately!`

Use `fail_immediately!` when you need to halt execution immediately AND rollback any database transactions. Unlike `stop_immediately!`, this method adds an error and causes transaction rollback.

```ruby
class Payment::Process < ApplicationService
  arg :amount, type: Integer
  arg :card_token, type: String

  step :validate_card
  step :charge_card
  step :send_receipt

  output :transaction_id, type: String

  private

  def validate_card
    unless valid_card?(card_token)
      fail_immediately!("Card validation failed")
    end
    
    # This code won't run if card is invalid
    log_validation_success
  end

  def charge_card
    # This step won't run if fail_immediately! was called
    self.transaction_id = PaymentGateway.charge(amount, card_token)
  end
end
```

{% hint style="info" %}
`fail_immediately!` raises an internal exception to halt execution. Steps marked with `always: true` will still run when `fail_immediately!` is called, allowing for cleanup operations.
{% endhint %}

{% hint style="danger" %}
**Database Transactions:** Calling `fail_immediately!` DOES rollback database transactions. All database changes made before `fail_immediately!` was called will be rolled back.
{% endhint %}

### Comparison Table

| Method | Adds Error | Stops Execution | Transaction Rollback |
|--------|------------|-----------------|---------------------|
| `stop!` | No | After current step | No |
| `stop_immediately!` | No | Immediately | No |
| `fail!(msg)` | Yes (:base) | After current step* | No |
| `fail_immediately!(msg)` | Yes (:base) | Immediately | Yes |

*By default, adding an error stops subsequent steps from running due to `break_on_add` configuration.

## Removing Inherited Steps

When inheriting from a parent service, you can remove steps using `remove_step`:

```ruby
class UpdateRecordService < ApplicationService
  step :authorize
  step :validate
  step :update_record
  step :send_notification
end

class InternalUpdate < UpdateRecordService
  # Remove authorization for internal system updates
  remove_step :authorize
  remove_step :send_notification
end
```

## Using `run` Method as a Simple Alternative

For simple services that don't need multiple steps, you can define a `run` method instead of using the `step` DSL. If no steps are defined, Operandi will automatically use the `run` method as a single step.

```ruby
class User::SendWelcomeEmail < ApplicationService
  arg :user, type: User

  private

  def run
    Mailer.welcome(user).deliver_later
  end
end
```

This is equivalent to:

```ruby
class User::SendWelcomeEmail < ApplicationService
  arg :user, type: User

  step :run

  private

  def run
    Mailer.welcome(user).deliver_later
  end
end
```

### Inheritance with `run` Method

The `run` method works with inheritance. If a parent service defines a `run` method, child services will inherit it:

```ruby
class BaseNotificationService < ApplicationService
  arg :message, type: String

  private

  def run
    send_notification(message)
  end

  def send_notification(msg)
    raise NotImplementedError
  end
end

class SlackNotification < BaseNotificationService
  private

  def send_notification(msg)
    SlackClient.post(msg)
  end
end

class EmailNotification < BaseNotificationService
  private

  def send_notification(msg)
    Mailer.notify(msg).deliver_later
  end
end
```

{% hint style="info" %}
If a service has no steps defined and no `run` method (including from parent classes), a `Operandi::NoStepsError` will be raised when the service is executed.
{% endhint %}

# What's Next?

Next step is to learn about outputs. Outputs are the results of a service, returned upon completion of service execution.

[Next: Outputs](outputs.md)
