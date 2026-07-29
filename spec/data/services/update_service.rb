# frozen_string_literal: true

class UpdateService < ApplicationService
  # Arguments
  arg :params, type: Hash, default: {}

  # Outputs
  output :entity

  # Steps
  step :load_entity
  step :assign_attributes
  step :authorize
  step :validate
  step :save
  step :log_action

  private

  def argument_key
    raise NotImplementedError
  end

  def filtered_params
    raise NotImplementedError
  end

  def load_entity
    self.entity = arg.get(argument_key)
  end

  def assign_attributes
    entity.assign_attributes(filtered_params)
  end

  def authorize
    # TODO: Implement this method
  end

  def validate
    return if entity.valid?

    errors.copy_from(entity)
  end

  def save
    entity.save!
  rescue ActiveRecord::RecordInvalid
    errors.copy_from(entity)
  end

  def log_action
    # Save information about this action anywhere
  end
end
