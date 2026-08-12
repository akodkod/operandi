# CRUD

In this recipe we'll create top-level CRUD services to manage our records.

This approach has been tested in production for many years and has saved significant time and effort.

## Why

We want to put all the common logic for creating, updating, destroying and finding records in one place.

We want to minimize possibility of a mistake by putting logic as close to core as possible.

## How to use it in controllers

```ruby
class PostsController < ApplicationController
  def index
    render json: crud_find_all(Post)
  end

  def show
    render json: crud_find(Post)
  end

  def create
    render_service crud_create(Post)
  end

  def update
    render_service crud_update(Post)
  end

  def destroy
    render_service crud_destroy(Post)
  end
end
```

{% hint style="info" %}
`render_service` method is a method from [Rendering Services](service-rendering.md) recipe.
{% endhint %}

## How to use it in services

```ruby
class ParseProfiles < ApplicationService
  # ...

  def create_profiles
    profiles.each do |profile|
      # Create profile service is automatically run within the same context
      create(
        Profile,
        name: profile.name,
        age: profile.age,
      )
    end
  end
end
```

## Customization

You don't need to create a new service for every CRUD operation. But you can create a service for specific model if you need to customize the behavior.

Just create a service called `{Model}::Create`, `{Model}::Update`, `{Model}::Destroy` and inherit from `CreateRecordService`, `UpdateRecordService`, `DestroyRecordService` respectively.

For example:

**Adding additional steps to create user:**

```ruby
class User::Create < CreateRecordService
  step :create_profile

  private

  def create_profile
    create!(Profile, user:)
  end
end
```

**Setting default attributes:**

```ruby
class Post::Create < CreateRecordService
  private

  def default_attributes
    { status: :draft }
  end
end
```

**Override attributes:**

```ruby
class Post::Update < UpdateRecordService
  private

  def override_attributes
    { updated_by: current_user }
  end
end
```

**Skipping step:**

```ruby
class Post::Destroy < DestroyRecordService
  remove_step :authorize
end
```

## Code

{% hint style="info" %}
This code is just a starting point. You can customize it to fit your needs.
{% endhint %}

{% hint style="info" %}
You need to add `Pundit Authorization` and `Request Concern` to make this code work.
{% endhint %}

**app/services/create\_record\_service.rb:**

```ruby
class CreateRecordService < ApplicationService
  # Arguments
  arg :record_class, type: Class, default: -> { self.class.module_parent }
  arg :attributes, type: Hash, default: {}

  # Steps
  step :create_alias
  step :authorize_user
  step :initialize_record
  step :assign_attributes
  step :save_record

  # Outputs
  output :record

  private

  # Create a readable alias for the record based on the class name (e.g. `user` for `User`)
  def create_alias
    define_singleton_method(record_class.to_s.underscore) { record }
  end

  # Check if the user is authorized to create a record
  def authorize_user
    auth(record_class, :create?)
  end

  # Initialize a new record
  def initialize_record
    self.record = record_class.new
  end

  # Assign attributes to the record
  def assign_attributes
    assign_attributes = default_attributes
      .merge(params_attributes)
      .merge(attributes)
      .merge(override_attributes)

    record.assign_attributes(assign_attributes)
  end

  # Save the record
  def save_record
    record.save_with!(self)
  end

  # Extract permitted attributes using Pundit
  def params_attributes
    return {} if !attributes.nil? && !(attributes.respond_to?(:empty?) && attributes.empty?)

    permitted_attributes(record, :create)
  rescue ActionController::ParameterMissing
    {}
  rescue Pundit::NotDefinedError
    raise unless system

    {}
  end

  # Default attributes, which can be overridden in subclasses
  def default_attributes
    {}
  end

  # Override attributes, which can be overridden in subclasses
  def override_attributes
    {}
  end
end
```

**app/services/update\_record\_service.rb:**

```ruby
class UpdateRecordService < ApplicationService
  # Arguments
  arg :record, type: ActiveRecord::Base
  arg :attributes, type: Hash, default: {}

  # Steps
  step :create_alias
  step :validate_record_class
  step :authorize_user
  step :assign_attributes
  step :save_record

  private

  # Create a readable alias for the record based on the class name (e.g. `user` for `User`)
  def create_alias
    define_singleton_method(record.class.to_s.underscore) { record }
  end

  # Make sure record is an instance of the correct class
  def validate_record_class
    return if self.class.module_parent == Object # No parent module
    return if self.class.module_parent == record.class

    errors.add(:base, "record must be #{self.class.module_parent}")
  end

  # Check if the user is authorized to update this record
  def authorize_user
    auth(record, :update?) if attributes.nil? || (attributes.respond_to?(:empty?) && attributes.empty?)
  end

  # Assign attributes to the record
  def assign_attributes
    assign_attributes = default_attributes
      .merge(params_attributes)
      .merge(attributes)
      .merge(override_attributes)

    record.assign_attributes(assign_attributes)
  end

  # Save the record
  def save_record
    record.save!
  rescue ActiveRecord::RecordInvalid
    errors.copy_from(record)
  end

  # Extract permitted attributes from params using Pundit
  def params_attributes
    return {} if !attributes.nil? && !(attributes.respond_to?(:empty?) && attributes.empty?)

    permitted_attributes(record, :update)
  rescue ActionController::ParameterMissing
    {}
  rescue Pundit::NotDefinedError
    raise unless system

    {}
  end

  # Default attributes, which can be overridden in subclasses
  def default_attributes
    {}
  end

  # Overridden attributes, which can be overridden in subclasses
  def override_attributes
    {}
  end
end
```

**app/services/destroy\_record\_service.rb:**

```ruby
class DestroyRecordService < ApplicationService
  # Arguments
  arg :record, type: ActiveRecord::Base
  arg :attributes, type: Hash, default: {}

  # Steps
  step :create_alias
  step :authorize_user
  step :destroy_record

  private

  # Create a readable alias for the record based on the class name (e.g. `user` for `User`)
  def create_alias
    define_singleton_method(record.class.to_s.underscore) { record }
  end

  # Check if the user is authorized to update this record
  def authorize_user
    auth(record, :destroy?)
  end

  # Delete the record
  def destroy_record
    record.destroy!
  rescue ActiveRecord::RecordNotDestroyed
    errors.copy_from(record)
  end
end
```

**app/controller/application\_controller.rb:**

```ruby
class ApplicationController < ActionController::Base
  # Includes
  include CRUDControllers
  include AuthenticateUser

  private

  def service_args(hash = {})
    hash.reverse_merge(
      params:,
      request:,
      current_user:,
      current_administrator:,
    )
  end
end
```

**app/controllers/concerns/crud\_controllers.rb:**

```ruby
module CRUDControllers
  extend ActiveSupport::Concern

  included do
    def crud_find(klass, args = {})
      crud_service(
        klass,
        "Find",
        FindRecordService,
        args.merge(record_class: klass),
      ).record
    end

    def crud_find_all(klass, args = {})
      crud_service(
        klass,
        "FindAll",
        FindAllRecordsService,
        args.merge(record_class: klass),
      ).scope
    end

    def crud_create(klass, args = {})
      crud_service(
        klass,
        "Create",
        CreateRecordService,
        args.merge(record_class: klass),
      )
    end

    def crud_update(record, args = {})
      crud_service(
        record.class,
        "Update",
        UpdateRecordService,
        args.merge(record:),
      )
    end

    def crud_destroy(record, args = {})
      crud_service(
        record.class,
        "Destroy",
        DestroyRecordService,
        args.merge(record:),
      )
    end

    private

    def crud_service(klass, class_postfix, default_class, args)
      begin
        service_class = "#{klass}::#{class_postfix}".constantize
      rescue NameError
        service_class = default_class
      end

      service_class.run(**service_args(args))
    end
  end
end
```

**app/services/application\_service.rb:**

```ruby
class ApplicationService < Operandi::Base
  # Includes
  include CRUDServices
  include RequestConcern
end
```

**app/services/concerns/crud\_services.rb:**

```ruby
module CRUDServices
  extend ActiveSupport::Concern

  included do
    def find(klass, args = {})
      run_service(
        klass,
        "Find",
        FindRecordService,
        args.merge(record_class: klass),
      )
    end

    def find_all(klass, args = {})
      args.reverse_merge!(no_filters: true)

      run_service(
        klass,
        "FindAll",
        FindAllRecordsService,
        args.merge(record_class: klass),
        plural_output: true,
      )
    end

    def create(klass, attributes = {}, args = {})
      run_service(
        klass,
        "Create",
        CreateRecordService,
        args.merge(record_class: klass, attributes:),
      )
    end

    def create!(klass, attributes = {}, args = {})
      create(klass, attributes, args.merge(raise_on_error: true))
    end

    def update(record, attributes = {}, args = {})
      run_service(
        record.class,
        "Update",
        UpdateRecordService,
        args.merge(record:, attributes:),
      )
    end

    def update!(record, attributes = {}, args = {})
      update(record, attributes, args.merge(raise_on_error: true))
    end

    def destroy(record, args = {})
      run_service(
        record.class,
        "Destroy",
        DestroyRecordService,
        args.merge(record:),
      )
    end

    def destroy!(record, args = {})
      destroy(record, args.merge(raise_on_error: true))
    end

    def create_or_update!(klass, record, attributes = {}, args = {})
      if record
        update!(record, attributes, args)
      else
        create!(klass, attributes, args)
      end
    end

    private

    def resource_name(klass, plural: false)
      name = klass.name.demodulize.underscore
      plural ? name.pluralize : name
    end

    def run_service(klass, class_postfix, default_class, args, opts = {})
      begin
        service_class = "#{klass}::#{class_postfix}".constantize
      rescue NameError
        service_class = default_class
      end

      service_class
        .with(self)
        .run(**args)
        .public_send(resource_name(klass, plural: opts[:plural_output]))
    end
  end
end
```

**app/services/concerns/request\_concern.rb:**

```ruby
module RequestConcern
  extend ActiveSupport::Concern

  included do
    arg :params, type: [Hash, ActionController::Parameters], default: ActionController::Parameters.new({}), context: true
    arg :request, type: ActionDispatch::Request, default: ActionDispatch::Request.new({}), context: true
  end
end
```

## What's Next?

Learn how to render service results cleanly in your controllers:

[Next: Service Rendering](service-rendering.md)
