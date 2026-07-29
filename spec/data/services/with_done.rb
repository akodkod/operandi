# frozen_string_literal: true

class WithDone < ApplicationService
  # Arguments
  arg :add_c, type: [TrueClass, FalseClass], default: false
  arg :do_not_add_d, type: [TrueClass, FalseClass], default: true
  arg :fake_error, type: [TrueClass, FalseClass], default: false

  # Outputs
  output :word, default: ""

  # Steps
  step :letter_a, if: -> { true }
  step :letter_b, unless: -> { false }
  step :letter_c, if: :add_c?
  step :letter_d, unless: :do_not_add_d?
  step :add_error, if: :fake_error?
  step :replace_word, always: true

  private

  def letter_a
    self.word += "a"
  end

  def letter_b
    self.word += "b"

    stop!

    self.word += "!" unless stopped?
  end

  def letter_c
    self.word += "c"
  end

  def letter_d
    self.word += "d"
  end

  def add_error
    errors.add(:base, "no words today")
  end

  def replace_word
    return if success?

    self.word = "error"

    warnings.add(:word, "was replaced")
  end
end
