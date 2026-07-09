# frozen_string_literal: true

require "sorbet-runtime"

class SorbetNotificationStatus < T::Enum
  enums do
    Queued = new("queued")
    Sent = new("sent")
  end
end

class WithSorbetTypes < ApplicationService
  # Arguments with Sorbet runtime type validation
  # Plain Ruby classes are automatically coerced to Sorbet types when sorbet-runtime is loaded
  arg :name, type: String
  arg :age, type: Integer
  arg :email, type: T.nilable(String), optional: true
  arg :status, type: T.any(String, Symbol), default: "pending"
  arg :tags, type: T::Array[String], optional: true
  arg :active, type: T::Boolean, optional: true
  arg :notification_status, type: SorbetNotificationStatus, default: "queued"
  arg :optional_notification_status, type: SorbetNotificationStatus, optional: true

  # Outputs with Sorbet runtime type validation
  output :greeting, type: String
  output :user_age, type: Integer
  output :full_data, type: Hash, optional: true

  # Steps
  step :build_greeting
  step :set_age
  step :build_data

  private

  def build_greeting
    self.greeting = "Hello, #{name}!"
  end

  def set_age
    self.user_age = age
  end

  def build_data
    self.full_data = {
      name: name,
      age: user_age,
      status: status,
      tags: tags || [],
      email: email,
      active: active,
      notification_status: notification_status,
      optional_notification_status: optional_notification_status,
    }
  end
end
