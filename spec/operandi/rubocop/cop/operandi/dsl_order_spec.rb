# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require "operandi/rubocop"

RSpec.describe RuboCop::Cop::Operandi::DslOrder, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when DSL order is correct" do
    it "does not register an offense for correct order" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          config raise_on_error: true

          arg :name, type: String
          arg :email, type: String

          step :validate
          step :process

          output :result, type: Hash
          output :message, type: String
        end
      RUBY
    end

    it "does not register an offense for partial DSL usage" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          arg :name, type: String

          step :process

          output :result, type: Hash
        end
      RUBY
    end

    it "does not register an offense for args and steps only" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          arg :name, type: String

          step :process
        end
      RUBY
    end

    it "does not register an offense for config only" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          config raise_on_error: true
        end
      RUBY
    end
  end

  context "when DSL order is incorrect" do
    it "registers an offense when arg comes after step" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process
          arg :name, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `arg` should come before `step`. Expected order: config → arg → step → output.
        end
      RUBY
    end

    it "registers an offense when config comes after arg" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          arg :name, type: String
          config raise_on_error: true
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `config` should come before `arg`. Expected order: config → arg → step → output.
        end
      RUBY
    end

    it "registers an offense when output comes before step" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          arg :name, type: String
          output :result, type: Hash
          step :process
          ^^^^^^^^^^^^^ Operandi/DslOrder: `step` should come before `output`. Expected order: config → arg → step → output.
        end
      RUBY
    end

    it "registers an offense when config comes last" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          arg :name, type: String
          step :process
          output :result, type: Hash
          config raise_on_error: true
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `config` should come before `output`. Expected order: config → arg → step → output.
        end
      RUBY
    end

    it "registers multiple offenses for completely reversed order" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          output :result, type: Hash
          step :process
          ^^^^^^^^^^^^^ Operandi/DslOrder: `step` should come before `output`. Expected order: config → arg → step → output.
          arg :name, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `arg` should come before `output`. Expected order: config → arg → step → output.
          config raise_on_error: true
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `config` should come before `output`. Expected order: config → arg → step → output.
        end
      RUBY
    end
  end

  context "with multiple items of same type" do
    it "does not register an offense for grouped items in correct order" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          arg :name, type: String
          arg :email, type: String
          arg :age, type: Integer

          step :validate
          step :process
          step :notify

          output :result, type: Hash
          output :message, type: String
        end
      RUBY
    end

    it "registers an offense when items are interleaved incorrectly" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          arg :name, type: String
          step :validate
          arg :email, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `arg` should come before `step`. Expected order: config → arg → step → output.
        end
      RUBY
    end
  end

  context "when DSL method names are used inside methods" do
    it "does not register an offense for arg used inside a method" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          arg :provider, type: String

          step :fetch_user_profile

          output :profile, type: Hash

          private

          def fetch_user_profile
            provider = arg.provider
          end
        end
      RUBY
    end

    it "does not register an offense for output used inside a method" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          arg :name, type: String

          step :process

          output :result, type: Hash

          private

          def process
            output.result = { name: arg.name }
          end
        end
      RUBY
    end
  end

  context "without class definition" do
    it "does not crash on DSL calls outside a class" do
      expect_no_offenses(<<~RUBY)
        arg :name, type: String
        step :process
      RUBY
    end
  end

  context "with autocorrect" do
    it "reorders simple DSL declarations" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process
          arg :name, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `arg` should come before `step`. Expected order: config → arg → step → output.
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          arg :name, type: String

          step :process
        end
      RUBY
    end

    it "reorders completely reversed DSL declarations" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          output :result, type: Hash
          step :process
          ^^^^^^^^^^^^^ Operandi/DslOrder: `step` should come before `output`. Expected order: config → arg → step → output.
          arg :name, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `arg` should come before `output`. Expected order: config → arg → step → output.
          config raise_on_error: true
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `config` should come before `output`. Expected order: config → arg → step → output.
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          config raise_on_error: true

          arg :name, type: String

          step :process

          output :result, type: Hash
        end
      RUBY
    end

    it "reorders with multiple items of same type" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :validate
          step :process
          arg :name, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `arg` should come before `step`. Expected order: config → arg → step → output.
          arg :email, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `arg` should come before `step`. Expected order: config → arg → step → output.
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          arg :name, type: String
          arg :email, type: String

          step :validate
          step :process
        end
      RUBY
    end

    it "preserves leading comments when reordering" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process
          # User's name
          arg :name, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/DslOrder: `arg` should come before `step`. Expected order: config → arg → step → output.
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          # User's name
          arg :name, type: String

          step :process
        end
      RUBY
    end
  end
end
