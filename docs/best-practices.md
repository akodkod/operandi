# Best Practices

This guide explores best practices for building applications with Operandi, keeping things simple and effective.

## Create Top-Level Services

Creating top-level services for your application is highly recommended. This approach helps keep your services small and focused on a single task.

### Application Service

`ApplicationService` serves as the base class for all services in your application. Use it to place common methods, helpers, context arguments, etc. Remember, it should not contain any business logic.

### Create, Update, and Destroy Services

Since create, update, and destroy are fundamental operations in any application, having dedicated services for them is a good idea. This keeps important tasks like authorization, data sanitization, and WebSocket broadcasts close to the core of your application.

- `CreateRecordService` - for creating records
- `UpdateRecordService` - for updating records
- `DestroyRecordService` - for destroying records

Think of these services as wrappers around the `ActiveRecord::Base#create`, `#update`, and `#destroy` methods.

### Read Services

Similar to the above services but focused on finding records. Use these for generic authorization, filtering, sorting, pagination, etc.

- `FindRecordService` - for finding a single record
- `FindAllRecordsService` - for finding multiple records

## Avoid Defining Context Arguments Outside Top-Level Services

Using context arguments outside of top-level services can make your services less modular and more unpredictable. Keep them within the core services for better modularity.

## Keep Services Small

Aim to keep your services small and focused on a single task. Ideally, a service should have no more than 3-5 steps. If a service has more steps, consider splitting it into multiple services.

## Passing Arguments from Controllers

It's a good practice to create a wrapper method to extend arguments passed to the service from the controller.

Consider this example controller:

```ruby
class PostsController < ApplicationController
  def index
    service = Post::FindAll.run(current_user:, current_organization:)
    render json: service.posts
  end

  def create
    service = Post::Create.run(attributes: params[:post], current_user:, current_organization:)

    if service.success?
      render json: service.post
    else
      render json: { errors: service.errors }, status: :unprocessable_entity
    end
  end

  def unpublish
    service = Post::Unpublish.run(id: params[:id], current_user:, current_organization:)

    if service.success?
      render json: service.post
    else
      render json: { errors: service.errors }, status: :unprocessable_entity
    end
  end

  # ...
end
```

Manually passing `current_user` and `current_organization` each time can be cumbersome. Let's simplify it with a helper method in our `ApplicationController`:

```ruby
class ApplicationController < ActionController::API
  private

  def service_args(hash = {})
    hash.reverse_merge(
      current_user:,
      current_organization:,
    )
  end
end
```

Now we can refactor our controller:

```ruby
class PostsController < ApplicationController
  def index
    service = Post::FindAll.run(**service_args)
    render json: service.posts
  end

  def create
    service = Post::Create.run(**service_args(attributes: params[:post]))

    if service.success?
      render json: service.post
    else
      render json: { errors: service.errors }, status: :unprocessable_entity
    end
  end

  def unpublish
    service = Post::Unpublish.run(**service_args(id: params[:id]))

    if service.success?
      render json: service.post
    else
      render json: { errors: service.errors }, status: :unprocessable_entity
    end
  end

  # ...
end
```

With this setup, adding a new top-level context argument only requires a change to the `service_args` method in `ApplicationController`.

## Use Concerns

If you have common logic that you want to share between services, use concerns. Avoid putting too much logic into your `ApplicationService` class; it's better to split it into concerns.

For example, create an `AuthorizeUser` concern for authorization logic.

```ruby
# app/services/concerns/authorize_user.rb
module AuthorizeUser
  extend ActiveSupport::Concern

  included do
    # ...
  end
end
```

```ruby
# app/services/application_service.rb
class ApplicationService < Operandi::Base
  include AuthorizeUser
end
```

## What's Next?

Explore practical recipes for common patterns:

[Next: Recipes](recipes.md)
