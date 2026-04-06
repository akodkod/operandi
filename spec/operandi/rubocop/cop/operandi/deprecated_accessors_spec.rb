# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require "operandi/rubocop"

RSpec.describe RuboCop::Cop::Operandi::DeprecatedAccessors, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when using arguments in a service class" do
    it "registers an offense for arguments" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            arguments[:name]
            ^^^^^^^^^ Operandi/DeprecatedAccessors: Use `arg` instead of deprecated `arguments`.
          end
        end
      RUBY
    end

    it "registers an offense for self.arguments" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            self.arguments[:name]
            ^^^^^^^^^^^^^^ Operandi/DeprecatedAccessors: Use `arg` instead of deprecated `arguments`.
          end
        end
      RUBY
    end

    it "autocorrects arguments to arg" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            arguments[:name]
            ^^^^^^^^^ Operandi/DeprecatedAccessors: Use `arg` instead of deprecated `arguments`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            arg[:name]
          end
        end
      RUBY
    end

    it "autocorrects self.arguments to self.arg" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            self.arguments[:name]
            ^^^^^^^^^^^^^^ Operandi/DeprecatedAccessors: Use `arg` instead of deprecated `arguments`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            self.arg[:name]
          end
        end
      RUBY
    end
  end

  context "when using outputs in a service class" do
    it "registers an offense for outputs" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            outputs[:result]
            ^^^^^^^ Operandi/DeprecatedAccessors: Use `output` instead of deprecated `outputs`.
          end
        end
      RUBY
    end

    it "registers an offense for self.outputs" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            self.outputs[:result]
            ^^^^^^^^^^^^ Operandi/DeprecatedAccessors: Use `output` instead of deprecated `outputs`.
          end
        end
      RUBY
    end

    it "autocorrects outputs to output" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            outputs[:result]
            ^^^^^^^ Operandi/DeprecatedAccessors: Use `output` instead of deprecated `outputs`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            output[:result]
          end
        end
      RUBY
    end

    it "autocorrects self.outputs to self.output" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            self.outputs[:result]
            ^^^^^^^^^^^^ Operandi/DeprecatedAccessors: Use `output` instead of deprecated `outputs`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            self.output[:result]
          end
        end
      RUBY
    end
  end

  context "when using both arguments and outputs in a service class" do
    it "registers offenses for both and autocorrects" do # rubocop:disable RSpec/ExampleLength
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            arguments[:name]
            ^^^^^^^^^ Operandi/DeprecatedAccessors: Use `arg` instead of deprecated `arguments`.
            outputs[:result]
            ^^^^^^^ Operandi/DeprecatedAccessors: Use `output` instead of deprecated `outputs`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            arg[:name]
            output[:result]
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
            arguments[:name]
            ^^^^^^^^^ Operandi/DeprecatedAccessors: Use `arg` instead of deprecated `arguments`.
          end
        end
      RUBY
    end
  end

  context "when not in a service class" do
    it "does not register an offense for arguments outside a class" do
      expect_no_offenses(<<~RUBY)
        arguments[:name]
      RUBY
    end

    it "does not register an offense in a non-service class" do
      expect_no_offenses(<<~RUBY)
        class MyClass
          def process
            arguments[:name]
          end
        end
      RUBY
    end

    it "does not register an offense in a class not matching pattern" do
      expect_no_offenses(<<~RUBY)
        class MyWorker < BaseWorker
          def process
            arguments[:name]
          end
        end
      RUBY
    end
  end

  context "when arguments is called on a different receiver" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :process

          private

          def process
            other_object.arguments
          end
        end
      RUBY
    end
  end

  context "with custom BaseServiceClasses" do
    let(:config) do
      RuboCop::Config.new(
        "Operandi/DeprecatedAccessors" => {
          "BaseServiceClasses" => ["ApplicationService", "BaseCreator"],
        },
      )
    end

    it "detects deprecated accessors in classes inheriting from configured base classes" do
      expect_offense(<<~RUBY)
        class User::Create < BaseCreator
          def process
            arguments[:name]
            ^^^^^^^^^ Use `arg` instead of deprecated `arguments`.
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
              arguments[:name]
              ^^^^^^^^^ Operandi/DeprecatedAccessors: Use `arg` instead of deprecated `arguments`.
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
              arguments[:name]
            end
          end
        end
      RUBY
    end
  end
end
