# Service Rendering

This recipe provides a clean way to render service results and errors in your Rails controllers, reducing boilerplate and ensuring consistent API responses.

## The Problem

Without a helper, controller actions become repetitive:

```ruby
class PostsController < ApplicationController
  def create
    service = Post::Create.run(**service_args(attributes: params[:post]))

    if service.success?
      render json: service.post, status: :created
    else
      render json: { errors: service.errors.to_h }, status: :unprocessable_entity
    end
  end

  def update
    service = Post::Update.run(**service_args(record: @post, attributes: params[:post]))

    if service.success?
      render json: service.post
    else
      render json: { errors: service.errors.to_h }, status: :unprocessable_entity
    end
  end

  # ... same pattern repeated for every action
end
```

## The Solution

Create a `render_service` helper that handles success and failure automatically.

## Implementation

### Basic Helper

Add this to your `ApplicationController`:

```ruby
class ApplicationController < ActionController::API
  private

  def render_service(service, success_status: :ok, error_status: :unprocessable_entity)
    if service.success?
      yield(service) if block_given?
      render json: service_response(service), status: success_status
    else
      render json: { errors: service.errors.to_h }, status: error_status
    end
  end

  def service_response(service)
    # Returns the first output that is set
    service.class.outputs.each do |name, _|
      value = service.public_send(name)
      return value unless value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end
    
    {}
  end
end
```

### Usage

```ruby
class PostsController < ApplicationController
  def create
    render_service Post::Create.run(**service_args(attributes: params[:post])),
                   success_status: :created
  end

  def update
    render_service Post::Update.run(**service_args(record: @post))
  end

  def destroy
    render_service Post::Destroy.run(**service_args(record: @post))
  end
end
```

## Advanced Implementation

### With Custom Response Building

```ruby
class ApplicationController < ActionController::API
  private

  def render_service(service, **options)
    if service.success?
      render_service_success(service, options)
    else
      render_service_failure(service, options)
    end
  end

  def render_service_success(service, options)
    status = options[:success_status] || :ok
    
    response = if options[:response]
      options[:response]
    elsif options[:output]
      service.public_send(options[:output])
    else
      auto_detect_response(service)
    end

    render json: response, status: status
  end

  def render_service_failure(service, options)
    status = options[:error_status] || :unprocessable_entity
    
    render json: {
      errors: service.errors.to_h,
      warnings: service.warnings.to_h
    }.compact, status: status
  end

  def auto_detect_response(service)
    service.class.outputs.each do |name, _|
      value = service.public_send(name)
      return value unless value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end
    
    { success: true }
  end
end
```

### Usage with Options

```ruby
class PostsController < ApplicationController
  def create
    service = Post::Create.run(**service_args(attributes: params[:post]))
    
    render_service service,
                   success_status: :created,
                   output: :post
  end

  def bulk_create
    service = Post::BulkCreate.run(**service_args(items: params[:posts]))
    
    render_service service,
                   success_status: :created,
                   response: { posts: service.posts, count: service.posts.count }
  end
end
```

## With Serializers

If you're using a serializer library (like Alba, Blueprinter, or ActiveModel::Serializers):

```ruby
class ApplicationController < ActionController::API
  private

  def render_service(service, serializer: nil, **options)
    if service.success?
      response = auto_detect_response(service)
      response = serializer.new(response).to_h if serializer && response
      
      render json: response, status: options[:success_status] || :ok
    else
      render json: { errors: service.errors.to_h }, 
             status: options[:error_status] || :unprocessable_entity
    end
  end
end
```

```ruby
class PostsController < ApplicationController
  def show
    service = Post::Find.run(**service_args(id: params[:id]))
    render_service service, serializer: PostSerializer
  end
end
```

## Handling Different Error Types

```ruby
def render_service(service, **options)
  if service.success?
    render_service_success(service, options)
  else
    status = determine_error_status(service, options)
    render json: { errors: service.errors.to_h }, status: status
  end
end

private

def determine_error_status(service, options)
  return options[:error_status] if options[:error_status]
  
  # Map specific error keys to HTTP statuses
  return :not_found if service.errors[:record]&.any?
  return :forbidden if service.errors[:authorization]&.any?
  return :unauthorized if service.errors[:authentication]&.any?
  
  :unprocessable_entity
end
```

## What's Next?

Learn how to integrate Pundit authorization with Operandi:

[Next: Pundit Authorization](pundit-authorization.md)
