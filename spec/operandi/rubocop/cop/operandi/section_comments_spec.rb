# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require "operandi/rubocop"

RSpec.describe RuboCop::Cop::Operandi::SectionComments, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) do
    RuboCop::Config.new(
      "AllCops" => { "DisplayCopNames" => true },
      "Operandi/SectionComments" => { "Enabled" => true },
    )
  end

  context "with a single DSL declaration" do
    [:arg, :step, :output].each do |method|
      it "does not require a heading for a single #{method}" do
        expect_no_offenses(<<~RUBY)
          class MyService < ApplicationService
            #{method} :value
          end
        RUBY
      end

      it "does not count config or calls inside methods alongside #{method}" do
        expect_no_offenses(<<~RUBY)
          class MyService < ApplicationService
            config raise_on_error: true
            #{method} :value

            def process
              arg :name
              step :notify
              output :result
            end
          end
        RUBY
      end
    end

    it "counts declarations separately for nested classes" do
      expect_no_offenses(<<~RUBY)
        class Outer < ApplicationService
          step :process

          class Inner < ApplicationService
            arg :name, type: String
          end
        end
      RUBY
    end
  end

  context "when section comments are present" do
    it "allows descriptive comments between headings and declarations" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          # Arguments
          # priorities: list of processing_priorities to process (e.g. ["high", "medium"]). Empty means all.
          arg :priorities, type: Array, default: []

          # Steps
          # Process each selected priority.
          # Skip priorities with no pending work.
          step :process

          # Outputs
          # The processed results.
          output :results
        end
      RUBY
    end

    it "does not register an offense for arguments, steps, and outputs" do
      expect_no_offenses(<<~RUBY)
        class Billing::CreateSetupIntent < ApplicationService
          # Arguments
          arg :user, type: User

          # Steps
          step :check_permissions
          step :create_setup_intent

          # Outputs
          output :setup_intent

          private

          def check_permissions
          end
        end
      RUBY
    end

    it "does not register an offense when a section is omitted" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          # Steps
          step :process
          step :notify
        end
      RUBY
    end

    it "does not register an offense for arguments and outputs without steps" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          # Arguments
          arg :name, type: String

          # Outputs
          output :result, type: Hash
        end
      RUBY
    end

    it "does not register an offense for config above the first section" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          config raise_on_error: true

          # Arguments
          arg :name, type: String

          # Steps
          step :process
        end
      RUBY
    end

    it "does not register an offense when one heading covers a group" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          # Arguments
          arg :name, type: String

          arg :email, type: String
        end
      RUBY
    end

    it "does not register an offense for config between arguments" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          # Arguments
          arg :name, type: String

          config raise_on_error: true

          arg :email, type: String
        end
      RUBY
    end

    it "does not register an offense for DSL names used inside methods" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          # Steps
          step :process

          private

          def process
            value = arg.name
            output.result = value
          end
        end
      RUBY
    end

    it "does not register an offense for a class without DSL declarations" do
      expect_no_offenses(<<~RUBY)
        class MyService < ApplicationService
          config raise_on_error: true
        end
      RUBY
    end
  end

  context "when a section comment is missing" do
    it "registers an offense and inserts the heading" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          arg :user, type: User
          ^^^^^^^^^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Arguments` section comment before `arg` declarations.
          step :process
          ^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Steps` section comment before `step` declarations.
          output :result, type: Hash
          ^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Outputs` section comment before `output` declarations.
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          # Arguments
          arg :user, type: User
          # Steps
          step :process
          # Outputs
          output :result, type: Hash
        end
      RUBY
    end

    it "inserts a heading above the first declaration and keeps blank lines" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          arg :user, type: User
          ^^^^^^^^^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Arguments` section comment before `arg` declarations.

          step :process
          ^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Steps` section comment before `step` declarations.
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          # Arguments
          arg :user, type: User

          # Steps
          step :process
        end
      RUBY
    end

    it "preserves descriptive comments when inserting a heading" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          # Amount in cents
          arg :amount, type: Integer
          ^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Arguments` section comment before `arg` declarations.
          arg :email, type: String
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          # Amount in cents
          # Arguments
          arg :amount, type: Integer
          arg :email, type: String
        end
      RUBY
    end

    it "preserves RuboCop directives when inserting a heading" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          # rubocop:disable Naming/VariableNumber
          arg :address_1, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Arguments` section comment before `arg` declarations.
          arg :email, type: String
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          # rubocop:disable Naming/VariableNumber
          # Arguments
          arg :address_1, type: String
          arg :email, type: String
        end
      RUBY
    end

    it "registers an offense when a blank line separates the heading" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          # Arguments

          arg :name, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Arguments` section comment before `arg` declarations.
          arg :email, type: String
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          # Arguments

          # Arguments
          arg :name, type: String
          arg :email, type: String
        end
      RUBY
    end

    it "does not treat an inline comment on the previous line as a heading" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          config raise_on_error: true # keep
          arg :name, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Arguments` section comment before `arg` declarations.
          arg :email, type: String
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          config raise_on_error: true # keep
          # Arguments
          arg :name, type: String
          arg :email, type: String
        end
      RUBY
    end
  end

  context "when a section comment is wrong" do
    it "corrects the heading above descriptive comments" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          # Args
          ^^^^^^ Operandi/SectionComments: Section comment must be `# Arguments`.
          # The user's name.
          arg :name, type: String
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          # Arguments
          # The user's name.
          arg :name, type: String
        end
      RUBY
    end

    it "registers an offense and replaces the heading" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          # Args
          ^^^^^^ Operandi/SectionComments: Section comment must be `# Arguments`.
          arg :name, type: String
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          # Arguments
          arg :name, type: String
        end
      RUBY
    end

    it "registers an offense and aligns the heading with the declaration" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
        # Arguments
        ^^^^^^^^^^^ Operandi/SectionComments: Section comment must be `# Arguments`.
          arg :name, type: String
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          # Arguments
          arg :name, type: String
        end
      RUBY
    end
  end

  context "when section comments are out of order" do
    it "registers an offense and does not move code" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          # Steps
          step :process
          # Arguments
          arg :name, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/SectionComments: `# Arguments` section must come before `# Steps`. Expected order: Arguments → Steps → Outputs.
        end
      RUBY

      expect_no_corrections
    end

    it "inserts missing headings without reordering declarations" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          step :process
          ^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Steps` section comment before `step` declarations.
          arg :name, type: String
          ^^^ Operandi/SectionComments: `# Arguments` section must come before `# Steps`. Expected order: Arguments → Steps → Outputs.
          ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Arguments` section comment before `arg` declarations.
        end
      RUBY

      expect_correction(<<~RUBY)
        class MyService < ApplicationService
          # Steps
          step :process
          # Arguments
          arg :name, type: String
        end
      RUBY
    end

    it "registers an offense for a repeated earlier section" do
      expect_offense(<<~RUBY)
        class MyService < ApplicationService
          # Arguments
          arg :name, type: String
          # Steps
          step :process
          # Arguments
          arg :email, type: String
          ^^^^^^^^^^^^^^^^^^^^^^^^ Operandi/SectionComments: `# Arguments` section must come before `# Steps`. Expected order: Arguments → Steps → Outputs.
        end
      RUBY

      expect_no_corrections
    end
  end

  context "with nested classes" do
    it "checks each class body separately" do
      expect_offense(<<~RUBY)
        class Outer < ApplicationService
          # Steps
          step :process

          class Inner < ApplicationService
            arg :name, type: String
            ^^^^^^^^^^^^^^^^^^^^^^^ Operandi/SectionComments: Add a `# Arguments` section comment before `arg` declarations.
            arg :email, type: String
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class Outer < ApplicationService
          # Steps
          step :process

          class Inner < ApplicationService
            # Arguments
            arg :name, type: String
            arg :email, type: String
          end
        end
      RUBY
    end
  end
end
