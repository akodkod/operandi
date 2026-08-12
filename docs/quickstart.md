# Quickstart

Operandi are framework-agnostic and can be used in any Ruby project.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "operandi", "~> 3.0"
```

Or you can install it yourself by running:

```bash
bundle add operandi --version "~> 3.0"
```

## Create `ApplicationService`

{% hint style="info" %}
This step is optional but recommended. Creating a base class for your services can help organize your code. This base class will act as the parent for all your services, where you can include common logic such as helpers, logging, error handling, etc.
{% endhint %}

### For Rails Applications

If you're using Rails, you can use the install generator to set up Operandi automatically:

```bash
bin/rails generate operandi:install
```

This will create the `ApplicationService` base class, an initializer, and a spec file (if RSpec is detected). See [Rails Generators](generators.md) for more details.

### For Non-Rails Applications

First, create a folder for your services. The path will depend on the framework you are using. For Rails, you can create a folder in `app/services`.

```bash
mkdir app/services
```

Next, create your base class. You can name it as you wish, but we recommend `ApplicationService`.

```ruby
# app/services/application_service.rb
class ApplicationService < Operandi::Base
  # Add common arguments, callbacks, or helpers shared across all services.
  #
  # Example: Add a context argument for the current user
  # arg :current_user, type: User, optional: true, context: true
end
```

## Create Your First Service

Now let's create our first service. We'll make a simple service that returns a greeting message.

{% hint style="info" %}
**Rails users:** You can use the service generator to create services quickly:
```bash
bin/rails generate operandi:service GreetService --args=name --steps=greet --outputs=greeted
```
See [Rails Generators](generators.md) for more information.
{% endhint %}

```ruby
# app/services/greet_service.rb
class GreetService < ApplicationService
  # Arguments
  arg :name, type: String

  # Steps
  step :greet

  # Outputs
  output :greeted, type: [TrueClass, FalseClass], default: false

  private

  def greet
    puts "Hello, #{name}!"
    self.greeted = true
  end
end
```

## Run the Service

Now you can run your service from anywhere in your application.

```ruby
service = GreetService.run(name: "John")
service.greeted # => true
```

### Check for Success or Failure

```ruby
service = GreetService.run(name: "John")

if service.success?
  puts "Greeting sent!"
  puts service.greeted
else
  puts "Failed: #{service.errors.to_h}"
end
```

### Raise on Error with `run!`

Use `run!` when you want errors to raise exceptions instead of being collected:

```ruby
# This will raise Operandi::RuntimeError if any errors are added
service = GreetService.run!(name: "John")
```

This is equivalent to:

```ruby
service = GreetService.with(raise_on_error: true).run(name: "John")
```

{% hint style="info" %}
Looks easy, right? But this is just the beginning. Operandi can do much more 🚀
{% endhint %}

## What's Next?

Learn how to configure Operandi for your application:

[Next: Configuration](configuration.md)
