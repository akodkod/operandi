# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require "operandi/rubocop"

RSpec.describe RuboCop::Cop::Operandi::PreferFailMethod, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when using errors.add(:base, message) in a service class" do
    it "registers an offense for errors.add(:base, message)" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            errors.add(:base, "user is required")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY
    end

    it "autocorrects errors.add(:base, message) to fail!(message)" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            errors.add(:base, "user is required")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            fail!("user is required")
          end
        end
      RUBY
    end

    it "autocorrects with string interpolation" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            errors.add(:base, "user \#{name} is required")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            fail!("user \#{name} is required")
          end
        end
      RUBY
    end

    it "autocorrects with variable as message" do # rubocop:disable RSpec/ExampleLength
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            msg = "error occurred"
            errors.add(:base, msg)
            ^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            msg = "error occurred"
            fail!(msg)
          end
        end
      RUBY
    end

    it "autocorrects with additional options hash" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            errors.add(:base, "error", rollback: false)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            fail!("error", rollback: false)
          end
        end
      RUBY
    end

    it "autocorrects with method call as message" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            errors.add(:base, error_message)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            fail!(error_message)
          end
        end
      RUBY
    end

    it "autocorrects inside conditional statements" do # rubocop:disable RSpec/ExampleLength
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            if user.nil?
              errors.add(:base, "user is required")
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
            end
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            if user.nil?
              fail!("user is required")
            end
          end
        end
      RUBY
    end

    it "autocorrects with return statement" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            return errors.add(:base, "error") if condition
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            return fail!("error") if condition
          end
        end
      RUBY
    end

    it "autocorrects multiple occurrences in the same method" do # rubocop:disable RSpec/ExampleLength
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            errors.add(:base, "first error")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
            do_something
            errors.add(:base, "second error")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            fail!("first error")
            do_something
            fail!("second error")
          end
        end
      RUBY
    end

    it "autocorrects with I18n translation" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            errors.add(:base, I18n.t("errors.user_required"))
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            fail!(I18n.t("errors.user_required"))
          end
        end
      RUBY
    end
  end

  context "when inheriting from Operandi::Base directly" do
    it "registers an offense" do
      expect_offense(<<~RUBY)
        class MyService < Operandi::Base
          step :process

          private

          def process
            errors.add(:base, "error message")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY
    end

    it "autocorrects the offense" do
      expect_offense(<<~RUBY)
        class MyService < Operandi::Base
          step :process

          private

          def process
            errors.add(:base, "error message")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < Operandi::Base
          step :process

          private

          def process
            fail!("error message")
          end
        end
      RUBY
    end
  end

  context "when not using :base key" do
    it "does not register an offense for errors.add with different key" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            errors.add(:email, "is invalid")
          end
        end
      RUBY
    end

    it "does not register an offense for errors.add(:name, message)" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            errors.add(:name, "is required")
          end
        end
      RUBY
    end
  end

  context "when using errors.add(:base) without a message" do
    it "does not register an offense (invalid Operandi syntax)" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            errors.add(:base)
          end
        end
      RUBY
    end
  end

  context "when not in a service class" do
    it "does not register an offense outside a class" do
      expect_no_offenses(<<~RUBY)
        errors.add(:base, "error")
      RUBY
    end

    it "does not register an offense in a non-service class" do
      expect_no_offenses(<<~RUBY)
        class MyClass
          def process
            errors.add(:base, "error")
          end
        end
      RUBY
    end

    it "does not register an offense in a class not matching pattern" do
      expect_no_offenses(<<~RUBY)
        class MyWorker < BaseWorker
          def process
            errors.add(:base, "error")
          end
        end
      RUBY
    end
  end

  context "when errors is called on a different object" do
    let(:ruby_version) { 3.2 }

    it "does not register an offense for other_object.errors.add(:base, message)" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            user.errors.add(:base, "error")
          end
        end
      RUBY
    end

    it "does not register an offense for @record.errors.add(:base, message)" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            @record.errors.add(:base, "error")
          end
        end
      RUBY
    end

    it "does not crash on constant receiver add calls with omitted keyword values" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :add_to_registry

          private

          def add_to_registry
            Event::Registry.add(
              event_name:,
              event_class:,
            )
          end
        end
      RUBY
    end
  end

  context "with custom BaseServiceClasses" do
    let(:config) do
      RuboCop::Config.new(
        "Operandi/PreferFailMethod" => {
          "BaseServiceClasses" => ["ApplicationService", "BaseCreator"],
        },
      )
    end

    it "detects errors.add(:base) in classes inheriting from configured base classes" do
      expect_offense(<<~RUBY)
        class User::Create < BaseCreator
          def process
            errors.add(:base, "error")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY
    end

    it "autocorrects in custom base classes" do
      expect_offense(<<~RUBY)
        class User::Create < BaseCreator
          def process
            errors.add(:base, "error")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class User::Create < BaseCreator
          def process
            fail!("error")
          end
        end
      RUBY
    end
  end

  context "with nested classes" do
    it "only checks the innermost service class" do
      expect_offense(<<~RUBY)
        class OuterService < ApplicationService
          class InnerService < ApplicationService
            def process
              errors.add(:base, "error")
              ^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/PreferFailMethod: Use `fail!(...)` instead of `errors.add(:base, ...)`.
            end
          end
        end
      RUBY
    end

    it "does not register offense in nested non-service class" do
      expect_no_offenses(<<~RUBY)
        class OuterService < ApplicationService
          class Helper
            def process
              errors.add(:base, "error")
            end
          end
        end
      RUBY
    end
  end

  context "when parent class is a method call" do
    let(:config) do
      RuboCop::Config.new(
        "Operandi/PreferFailMethod" => {
          "BaseServiceClasses" => ["Services.base"],
        },
      )
    end

    it "detects errors.add(:base) when base class is determined by method call" do
      expect_offense(<<~RUBY)
        class MyService < Services.base
          def process
            errors.add(:base, "error")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `fail!(...)` instead of `errors.add(:base, ...)`.
          end
        end
      RUBY
    end

    it "does not register offense when method call does not match configured base classes" do
      expect_no_offenses(<<~RUBY)
        class MyService < Other.base
          def process
            errors.add(:base, "error")
          end
        end
      RUBY
    end
  end

  context "with warnings instead of errors" do
    it "does not register an offense for warnings.add(:base, message)" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            warnings.add(:base, "warning message")
          end
        end
      RUBY
    end
  end
end
