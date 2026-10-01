# frozen_string_literal: true

class WithNilAsDefault < ApplicationService
  config nil_as_default: true

  arg :name, type: String, default: "default_name"
  arg :title, type: String, optional: true, default: "default_title"
  arg :description, type: String, optional: true

  step :noop

  private

  def noop; end
end
