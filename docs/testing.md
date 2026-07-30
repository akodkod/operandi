# Testing

Testing Operandi is straightforward. This guide covers strategies for unit testing your services effectively.

## Basic Service Testing

### Testing a Simple Service

```ruby
# app/services/greet_service.rb
class GreetService < ApplicationService
  arg :name, type: String

  step :greet

  output :message

  private

  def greet
    self.message = "Hello, #{name}!"
  end
end
```

```ruby
# spec/services/greet_service_spec.rb
RSpec.describe GreetService do
  describe ".run" do
    it "returns a greeting message" do
      service = described_class.run(name: "John")

      expect(service).to be_successful
      expect(service.message).to eq("Hello, John!")
    end
  end
end
```

## Testing Success and Failure

```ruby
RSpec.describe User::Create do
  describe ".run" do
    context "with valid attributes" do
      let(:attributes) { { email: "test@example.com", password: "password123" } }

      it "creates a user" do
        service = described_class.run(attributes: attributes)

        expect(service).to be_successful
        expect(service.user).to be_persisted
        expect(service.user.email).to eq("test@example.com")
      end
    end

    context "with invalid attributes" do
      let(:attributes) { { email: "", password: "" } }

      it "returns errors" do
        service = described_class.run(attributes: attributes)

        expect(service).to be_failed
        expect(service.errors[:email]).to be_present
      end
    end
  end
end
```

## Testing with Context

When services use context to share data, test both scenarios:

```ruby
RSpec.describe Comment::Create do
  let(:current_user) { create(:user) }
  let(:post) { create(:post) }

  describe ".run" do
    context "with current_user in context" do
      it "creates a comment by the current user" do
        service = described_class.run(
          current_user: current_user,
          post_id: post.id,
          text: "Great post!"
        )

        expect(service).to be_successful
        expect(service.comment.user).to eq(current_user)
      end
    end

    context "without current_user" do
      it "fails with authorization error" do
        service = described_class.run(
          current_user: nil,
          post_id: post.id,
          text: "Great post!"
        )

        expect(service).to be_failed
        expect(service.errors[:authorization]).to be_present
      end
    end
  end
end
```

## Testing Child Services in Context

When testing services that call other services via `.with(self)`:

```ruby
RSpec.describe Order::Create do
  let(:current_user) { create(:user) }
  let(:product) { create(:product, price: 100) }

  it "creates order and order items in the same transaction" do
    service = described_class.run(
      current_user: current_user,
      items: [{ product_id: product.id, quantity: 2 }]
    )

    expect(service).to be_successful
    expect(service.order.order_items.count).to eq(1)
    expect(service.order.total).to eq(200)
  end

  it "rolls back everything if child service fails" do
    # Stub the child service to fail
    allow_any_instance_of(OrderItem::Create).to receive(:validate).and_wrap_original do |method, *args|
      method.receiver.errors.add(:base, "Simulated failure")
    end

    expect {
      described_class.run(
        current_user: current_user,
        items: [{ product_id: product.id, quantity: 2 }]
      )
    }.not_to change(Order, :count)
  end
end
```

## Testing Conditional Steps

```ruby
RSpec.describe User::Register do
  describe "conditional steps" do
    context "when send_welcome_email is true" do
      it "sends a welcome email" do
        expect {
          described_class.run(
            email: "test@example.com",
            password: "password123",
            send_welcome_email: true
          )
        }.to have_enqueued_mail(UserMailer, :welcome)
      end
    end

    context "when send_welcome_email is false" do
      it "does not send a welcome email" do
        expect {
          described_class.run(
            email: "test@example.com",
            password: "password123",
            send_welcome_email: false
          )
        }.not_to have_enqueued_mail(UserMailer, :welcome)
      end
    end
  end
end
```

## Testing Early Exit with stop!

```ruby
RSpec.describe User::FindOrCreate do
  describe "when user exists" do
    let!(:existing_user) { create(:user, email: "existing@example.com") }

    it "returns existing user without creating new one" do
      expect {
        service = described_class.run(email: "existing@example.com")
        expect(service.user).to eq(existing_user)
      }.not_to change(User, :count)
    end
  end

  describe "when user does not exist" do
    it "creates a new user" do
      expect {
        service = described_class.run(email: "new@example.com")
        expect(service.user.email).to eq("new@example.com")
      }.to change(User, :count).by(1)
    end
  end
end
```

## Testing Configuration Overrides

```ruby
RSpec.describe MyService do
  describe "with raise_on_error config" do
    it "raises exception when configured" do
      expect {
        described_class.run({ invalid: true }, { raise_on_error: true })
      }.to raise_error(Operandi::RuntimeError)
    end

    it "collects errors by default" do
      service = described_class.run(invalid: true)
      
      expect(service).to be_failed
      expect { service }.not_to raise_error
    end
  end
end
```

## Testing run! vs run

```ruby
RSpec.describe Payment::Process do
  context "using run" do
    it "returns failed service on error" do
      service = described_class.run(amount: -100)
      
      expect(service).to be_failed
      expect(service.errors[:amount]).to include("must be positive")
    end
  end

  context "using run!" do
    it "raises exception on error" do
      expect {
        described_class.run!(amount: -100)
      }.to raise_error(Operandi::RuntimeError, /Amount must be positive/)
    end
  end
end
```

## Testing Warnings

```ruby
RSpec.describe DataImport do
  it "completes with warnings for skipped records" do
    service = described_class.run(data: mixed_valid_invalid_data)

    expect(service).to be_successful # Warnings don't fail the service
    expect(service.warnings?).to be true
    expect(service.warnings[:skipped]).to include("Row 3: invalid format")
  end
end
```

## Mocking External Services

```ruby
RSpec.describe Payment::Charge do
  let(:stripe_client) { instance_double(Stripe::PaymentIntent) }

  before do
    allow(Stripe::PaymentIntent).to receive(:create).and_return(stripe_client)
    allow(stripe_client).to receive(:id).and_return("pi_123")
  end

  it "processes payment successfully" do
    service = described_class.run(amount: 1000, card_token: "tok_visa")

    expect(service).to be_successful
    expect(service.payment_intent_id).to eq("pi_123")
  end

  context "when Stripe fails" do
    before do
      allow(Stripe::PaymentIntent).to receive(:create)
        .and_raise(Stripe::CardError.new("Card declined", nil, nil))
    end

    it "handles the error gracefully" do
      service = described_class.run(amount: 1000, card_token: "tok_declined")

      expect(service).to be_failed
      expect(service.errors[:payment]).to include("Card declined")
    end
  end
end
```

## Testing Argument Validation

```ruby
RSpec.describe MyService do
  describe "argument validation" do
    it "requires name argument" do
      expect {
        described_class.run(name: nil)
      }.to raise_error(Operandi::ArgTypeError)
    end

    it "validates argument type" do
      expect {
        described_class.run(name: 123) # expects String
      }.to raise_error(Operandi::ArgTypeError, /must be a String/)
    end

    it "accepts optional arguments as nil" do
      service = described_class.run(name: "John", nickname: nil)
      expect(service).to be_successful
    end
  end
end
```

## Shared Examples for CRUD Services

```ruby
# spec/support/shared_examples/crud_service.rb
RSpec.shared_examples "a create service" do |model_class|
  let(:valid_attributes) { attributes_for(model_class.name.underscore.to_sym) }
  let(:current_user) { create(:user) }

  it "creates a record" do
    expect {
      described_class.run(current_user: current_user, attributes: valid_attributes)
    }.to change(model_class, :count).by(1)
  end

  it "returns the created record" do
    service = described_class.run(current_user: current_user, attributes: valid_attributes)
    expect(service.record).to be_a(model_class)
    expect(service.record).to be_persisted
  end
end

# Usage in specs
RSpec.describe Post::Create do
  it_behaves_like "a create service", Post
end
```

## Test Helpers

Create a helper module for common service testing patterns:

```ruby
# spec/support/service_helpers.rb
module ServiceHelpers
  def expect_service_success(service)
    expect(service).to be_successful, -> { "Expected success but got errors: #{service.errors.to_h}" }
  end

  def expect_service_failure(service, key = nil)
    expect(service).to be_failed
    expect(service.errors[key]).to be_present if key
  end
end

RSpec.configure do |config|
  config.include ServiceHelpers, type: :service
end
```

## Custom RSpec Matchers

Operandi provides built-in RSpec matchers to make testing more expressive and readable.

### Setup

Add this to your `spec/spec_helper.rb` or `spec/rails_helper.rb`:

```ruby
require 'operandi/rspec'
```

This automatically includes all matchers in your RSpec tests.

### DSL Definition Matchers

#### `define_argument`

Test that a service defines specific arguments:

```ruby
RSpec.describe User::Create do
  it { expect(described_class).to define_argument(:email) }
  it { expect(described_class).to define_argument(:email).with_type(String) }
  it { expect(described_class).to define_argument(:role).optional }
  it { expect(described_class).to define_argument(:status).with_default("pending") }
  it { expect(described_class).to define_argument(:current_user).with_context }
  
  # Chaining modifiers
  it { expect(described_class).to define_argument(:age).with_type(Integer).with_default(18) }
end
```

#### `define_output`

Test that a service defines specific outputs:

```ruby
RSpec.describe User::Create do
  it { expect(described_class).to define_output(:user) }
  it { expect(described_class).to define_output(:user).with_type(User) }
  it { expect(described_class).to define_output(:token).optional }
  it { expect(described_class).to define_output(:count).with_default(0) }
end
```

#### `define_step` and `define_steps`

Test that a service defines specific steps:

```ruby
RSpec.describe User::Create do
  # Single step
  it { expect(described_class).to define_step(:validate) }
  it { expect(described_class).to define_step(:cleanup).with_always(true) }
  it { expect(described_class).to define_step(:notify).with_if(:should_notify?) }
  it { expect(described_class).to define_step(:skip_log).with_unless(:logging_enabled?) }
  
  # Multiple steps
  it { expect(described_class).to define_steps(:validate, :process, :save) }
  
  # Steps in order
  it { expect(described_class).to define_steps_in_order(:validate, :process, :save) }
end
```

### Error and Warning Matchers

#### `have_error_on` and `have_errors_on`

Test service errors:

```ruby
RSpec.describe User::Create do
  context "with invalid email" do
    let(:service) { described_class.run(email: "") }
    
    it { expect(service).to have_error_on(:email) }
    it { expect(service).to have_error_on(:email).with_message("can't be blank") }
    it { expect(service).to have_error_on(:email).with_message(/blank/) } # regex
    
    # Multiple errors (requires break_on_error: false)
    it { expect(service).to have_errors_on(:email, :password) }
  end
end
```

#### `have_warning_on` and `have_warnings_on`

Test service warnings:

```ruby
RSpec.describe Data::Import do
  context "with deprecated format" do
    let(:service) { described_class.run(format: "csv_v1") }
    
    it { expect(service).to have_warning_on(:format) }
    it { expect(service).to have_warning_on(:format).with_message("format is deprecated") }
  end
end
```

### Execution Matchers

These matchers require step tracking. Add this to your service:

```ruby
class ApplicationService < Operandi::Base
  output :executed_steps, default: -> { [] }
  
  after_step_run do |service, step_name|
    service.executed_steps << step_name
  end
end
```

#### `execute_step` and `skip_step`

```ruby
RSpec.describe Order::Process do
  context "with premium user" do
    let(:service) { described_class.run(user: premium_user) }
    
    it { expect(service).to execute_step(:apply_discount) }
    it { expect(service).to skip_step(:show_ads) }
  end
end
```

#### `execute_steps` and `execute_steps_in_order`

```ruby
RSpec.describe Order::Process do
  let(:service) { described_class.run(order: order) }
  
  it { expect(service).to execute_steps(:validate, :charge, :fulfill) }
  it { expect(service).to execute_steps_in_order(:validate, :charge, :fulfill) }
end
```

### Callback Matchers

These matchers require callback tracking. Add this to your service:

```ruby
class ApplicationService < Operandi::Base
  output :callback_log, default: -> { [] }
  
  before_service_run { |service| service.callback_log << :before_service_run }
  after_service_run { |service| service.callback_log << :after_service_run }
  on_service_success { |service| service.callback_log << :on_service_success }
  on_service_failure { |service| service.callback_log << :on_service_failure }
  
  after_step_run { |service, step| service.callback_log << [:after_step_run, step] }
end
```

#### `trigger_callback`

```ruby
RSpec.describe Order::Process do
  context "when successful" do
    let(:service) { described_class.run(order: valid_order) }
    
    it { expect(service).to trigger_callback(:before_service_run) }
    it { expect(service).to trigger_callback(:on_service_success) }
    it { expect(service).not_to trigger_callback(:on_service_failure) }
    
    # Step-specific callbacks
    it { expect(service).to trigger_callback(:after_step_run).for_step(:validate) }
  end
end
```

## What's Next?

Learn best practices for organizing your services:

[Next: Best Practices](best-practices.md)
