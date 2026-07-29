# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require "operandi/rubocop"

RSpec.describe RuboCop::Cop::Operandi::ReservedName, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  describe "reserved argument names" do
    it "registers an offense for :errors" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          arg :errors, type: Array
          ^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/ReservedName: `errors` is a reserved name and cannot be used as an argument. It conflicts with Operandi methods.
        end
      RUBY
    end

    it "registers an offense for :output" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          arg :output, type: Hash
          ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/ReservedName: `output` is a reserved name and cannot be used as an argument. It conflicts with Operandi methods.
        end
      RUBY
    end

    it "registers an offense for :success?" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          arg :success?, type: [TrueClass, FalseClass]
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/ReservedName: `success?` is a reserved name and cannot be used as an argument. It conflicts with Operandi methods.
        end
      RUBY
    end

    it "registers an offense for :initialize" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          arg :initialize, type: Proc
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/ReservedName: `initialize` is a reserved name and cannot be used as an argument. It conflicts with Operandi methods.
        end
      RUBY
    end
  end

  describe "reserved step names" do
    it "registers an offense for :call" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :call
          ^^^^^^^^^^ Operandi/ReservedName: `call` is a reserved name and cannot be used as a step. It conflicts with Operandi methods.
        end
      RUBY
    end

    it "registers an offense for :initialize" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :initialize
          ^^^^^^^^^^^^^^^^ Operandi/ReservedName: `initialize` is a reserved name and cannot be used as a step. It conflicts with Operandi methods.
        end
      RUBY
    end

    it "registers an offense for :before_step_run" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :before_step_run
          ^^^^^^^^^^^^^^^^^^^^^ Operandi/ReservedName: `before_step_run` is a reserved name and cannot be used as a step. It conflicts with Operandi methods.
        end
      RUBY
    end

    it "registers an offense for :stop!" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :stop!
          ^^^^^^^^^^^ Operandi/ReservedName: `stop!` is a reserved name and cannot be used as a step. It conflicts with Operandi methods.
        end
      RUBY
    end
  end

  describe "reserved output names" do
    it "registers an offense for :success?" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          output :success?, type: [TrueClass, FalseClass]
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/ReservedName: `success?` is a reserved name and cannot be used as an output. It conflicts with Operandi methods.
        end
      RUBY
    end

    it "registers an offense for :warnings" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          output :warnings, type: Array
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/ReservedName: `warnings` is a reserved name and cannot be used as an output. It conflicts with Operandi methods.
        end
      RUBY
    end

    it "registers an offense for :errors" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          output :errors, type: Array
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/ReservedName: `errors` is a reserved name and cannot be used as an output. It conflicts with Operandi methods.
        end
      RUBY
    end

    it "registers an offense for :failed?" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          output :failed?, type: [TrueClass, FalseClass]
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/ReservedName: `failed?` is a reserved name and cannot be used as an output. It conflicts with Operandi methods.
        end
      RUBY
    end
  end

  describe "valid non-reserved names" do
    it "does not register an offense for non-reserved argument names" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          arg :user_id, type: Integer
          arg :params, type: Hash
          arg :validation_errors, type: Array
          arg :arguments, type: Hash
        end
      RUBY
    end

    it "does not register an offense for non-reserved step names" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          step :validate
          step :process
          step :execute
        end
      RUBY
    end

    it "does not register an offense for non-reserved output names" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          output :result, type: Hash
          output :user, type: User
          output :succeeded, type: [TrueClass, FalseClass]
          output :outputs, type: Hash
        end
      RUBY
    end
  end

  describe "edge cases" do
    it "handles multiple DSL calls with mixed reserved and valid names" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          arg :user_id, type: Integer
          arg :errors, type: Array
          ^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/ReservedName: `errors` is a reserved name and cannot be used as an argument. It conflicts with Operandi methods.
          step :validate
          step :call
          ^^^^^^^^^^ Operandi/ReservedName: `call` is a reserved name and cannot be used as a step. It conflicts with Operandi methods.
          output :result, type: Hash
          output :success?, type: [TrueClass, FalseClass]
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/ReservedName: `success?` is a reserved name and cannot be used as an output. It conflicts with Operandi methods.
        end
      RUBY
    end
  end
end
