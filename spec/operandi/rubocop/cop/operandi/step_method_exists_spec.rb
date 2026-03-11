# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require "operandi/rubocop"

RSpec.describe RuboCop::Cop::Operandi::StepMethodExists, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when step method is missing" do
    it "registers an offense for missing method" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :validate
          ^^^^^^^^^^^^^^ Operandi/StepMethodExists: Step `validate` has no corresponding method. For inherited steps, use `parent: true`, disable this line, or add to ExcludedSteps.
        end
      RUBY
    end

    it "registers an offense for each missing method" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :validate
          ^^^^^^^^^^^^^^ Operandi/StepMethodExists: Step `validate` has no corresponding method. For inherited steps, use `parent: true`, disable this line, or add to ExcludedSteps.
          step :process
          ^^^^^^^^^^^^^ Operandi/StepMethodExists: Step `process` has no corresponding method. For inherited steps, use `parent: true`, disable this line, or add to ExcludedSteps.
        end
      RUBY
    end

    it "registers an offense only for missing methods" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :validate
          step :process
          ^^^^^^^^^^^^^ Operandi/StepMethodExists: Step `process` has no corresponding method. For inherited steps, use `parent: true`, disable this line, or add to ExcludedSteps.

          private

          def validate
            # exists
          end
        end
      RUBY
    end
  end

  context "when all step methods exist" do
    it "does not register an offense for public methods" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :validate
          step :process

          def validate
            # validation
          end

          def process
            # processing
          end
        end
      RUBY
    end

    it "does not register an offense for private methods" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :validate
          step :process

          private

          def validate
            # validation
          end

          def process
            # processing
          end
        end
      RUBY
    end

    it "does not register an offense when methods are defined before steps" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          private

          def validate
            # validation
          end

          def process
            # processing
          end

          step :validate
          step :process
        end
      RUBY
    end
  end

  context "with step options" do
    it "does not register an offense when method exists with if condition" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :notify, if: :should_notify?

          private

          def notify
            # notification
          end

          def should_notify?
            true
          end
        end
      RUBY
    end

    it "does not register an offense when method exists with unless condition" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :skip_validation, unless: :production?

          private

          def skip_validation
            # skip
          end

          def production?
            false
          end
        end
      RUBY
    end

    it "does not register an offense when method exists with always option" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :cleanup, always: true

          private

          def cleanup
            # cleanup
          end
        end
      RUBY
    end

    it "does not register an offense when method exists with before/after options" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :validate
          step :log_start, before: :validate
          step :log_end, after: :validate

          private

          def validate
            # validation
          end

          def log_start
            # log
          end

          def log_end
            # log
          end
        end
      RUBY
    end
  end

  context "with proc conditions" do
    it "does not register an offense when method exists with proc if" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :premium_feature, if: -> { user.premium? }

          private

          def premium_feature
            # feature
          end
        end
      RUBY
    end
  end

  context "without class definition" do
    it "does not crash on step calls outside a class" do
      expect_no_offenses(<<~RUBY)
        step :something
      RUBY
    end
  end

  context "with parent option" do
    it "does not register an offense for step with parent: true" do
      expect_no_offenses(<<~RUBY)
        class User::Create < CreateService
          step :initialize_entity, parent: true
        end
      RUBY
    end

    it "only flags regular steps when mixed with parent steps" do
      expect_offense(<<~RUBY)
        class User::Create < CreateService
          step :initialize_entity, parent: true
          step :send_welcome_email
          ^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/StepMethodExists: Step `send_welcome_email` has no corresponding method. For inherited steps, use `parent: true`, disable this line, or add to ExcludedSteps.
        end
      RUBY
    end

    it "does not register an offense for parent: true combined with other options" do
      expect_no_offenses(<<~RUBY)
        class User::Create < CreateService
          step :initialize_entity, if: :should_init?, parent: true
          step :cleanup, always: true, parent: true
        end
      RUBY
    end

    it "still flags missing method when parent: false" do
      expect_offense(<<~RUBY)
        class User::Create < CreateService
          step :initialize_entity, parent: false
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/StepMethodExists: Step `initialize_entity` has no corresponding method. For inherited steps, use `parent: true`, disable this line, or add to ExcludedSteps.
        end
      RUBY
    end
  end

  context "with ExcludedSteps option" do
    let(:config) do
      RuboCop::Config.new(
        "Operandi/StepMethodExists" => {
          "ExcludedSteps" => ["initialize_entity", "assign_attributes", "save"],
        },
      )
    end

    it "does not register an offense for excluded steps" do
      expect_no_offenses(<<~RUBY)
        class User::Create < CreateService
          step :initialize_entity
          step :assign_attributes
          step :save
        end
      RUBY
    end

    it "still registers an offense for non-excluded missing methods" do
      expect_offense(<<~RUBY)
        class User::Create < CreateService
          step :initialize_entity
          step :assign_attributes
          step :send_welcome_email
          ^^^^^^^^^^^^^^^^^^^^^^^^ Step `send_welcome_email` has no corresponding method. For inherited steps, use `parent: true`, disable this line, or add to ExcludedSteps.
        end
      RUBY
    end

    it "does not register an offense when excluded and non-excluded steps have methods" do
      expect_no_offenses(<<~RUBY)
        class User::Create < CreateService
          step :initialize_entity
          step :assign_attributes
          step :send_welcome_email

          private

          def send_welcome_email
            # defined
          end
        end
      RUBY
    end
  end
end
