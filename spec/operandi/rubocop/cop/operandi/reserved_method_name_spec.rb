# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require "operandi/rubocop"

RSpec.describe RuboCop::Cop::Operandi::ReservedMethodName, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) do
    RuboCop::Config.new(
      "AllCops" => { "DisplayCopNames" => true },
      "Operandi/ReservedMethodName" => cop_config,
    )
  end
  let(:cop_config) { {} }

  ["Operandi::Base", "::Operandi::Base", "ApplicationService"].each do |base|
    it "rejects call in a subclass of #{base}" do
      expect_offense(<<~RUBY)
        class FetchTickets < #{base}
          def call; end
              ^^^^ Operandi/ReservedMethodName: `call` is reserved for Operandi internals. Use `run` or a named step instead.
        end
      RUBY
    end
  end

  described_class::RESERVED_METHODS.each do |name|
    it "rejects the reserved instance method #{name}" do
      expect_offense(<<~RUBY)
        class FetchTickets < ApplicationService
          private

          def #{name}; end
              #{'^' * name.length} Operandi/ReservedMethodName: `#{name}` is reserved for Operandi internals. Use `run` or a named step instead.
        end
      RUBY
    end
  end

  it "allows the supported run fallback and named steps" do
    expect_no_offenses(<<~RUBY)
      class FetchTickets < Operandi::Base
        def run; end
        def fetch_tickets; end
      end
    RUBY
  end

  it "ignores unrelated classes and modules nested inside a service" do
    expect_no_offenses(<<~RUBY)
      class FetchTickets < ApplicationService
        class Callable
          def call; end
        end
        module Helpers
          def call; end
        end
      end
      class Other < Object
        def call; end
      end
    RUBY
  end

  it "ignores singleton methods" do
    expect_no_offenses(<<~RUBY)
      class FetchTickets < ApplicationService
        def self.call; end
        class << self
          def call; end
        end
      end
    RUBY
  end

  it "resolves a base class declared in the same file" do
    expect_offense(<<~RUBY)
      class Parent < Operandi::Base; end
      class FetchTickets < Parent
        def call; end
            ^^^^ Operandi/ReservedMethodName: `call` is reserved for Operandi internals. Use `run` or a named step instead.
      end
    RUBY
  end

  it "rejects overriding the callback dispatcher" do
    expect_offense(<<~RUBY)
      class FetchTickets < ApplicationService
        def execute_callback; end
            ^^^^^^^^^^^^^^^^ Operandi/ReservedMethodName: `execute_callback` is reserved for Operandi internals. Use `run` or a named step instead.
      end
    RUBY
  end

  it "resolves the nearest lexical parent among identically named classes" do
    expect_offense(<<~RUBY)
      module Other
        class Parent; end
      end
      module Billing
        class Parent < Operandi::Base; end
        class FetchTickets < Parent
          def call; end
              ^^^^ Operandi/ReservedMethodName: `call` is reserved for Operandi internals. Use `run` or a named step instead.
        end
      end
    RUBY
  end

  it "ignores unrelated parents sharing a service parent's name" do
    expect_no_offenses(<<~RUBY)
      module Billing
        class Parent < Operandi::Base; end
      end
      module Other
        class Parent; end
        class Callable < Parent
          def call; end
        end
      end
    RUBY
  end

  it "resolves qualified references to nested declarations" do
    expect_offense(<<~RUBY)
      module Billing
        class Parent < Operandi::Base; end
      end
      class FetchTickets < Billing::Parent
        def call; end
            ^^^^ Operandi/ReservedMethodName: `call` is reserved for Operandi internals. Use `run` or a named step instead.
      end
    RUBY
  end

  it "resolves parents declared with qualified class names" do
    expect_offense(<<~RUBY)
      class Billing::Parent < Operandi::Base; end
      module Billing
        module Tickets
          class FetchTickets < Parent
            def call; end
                ^^^^ Operandi/ReservedMethodName: `call` is reserved for Operandi internals. Use `run` or a named step instead.
          end
        end
      end
    RUBY
  end

  it "respects absolute superclass references" do
    expect_no_offenses(<<~RUBY)
      class Parent; end
      module Billing
        class Parent < Operandi::Base; end
        class Callable < ::Parent
          def call; end
        end
      end
    RUBY
  end

  it "respects a local class shadowing a configured base name" do
    expect_no_offenses(<<~RUBY)
      module Other
        class ApplicationService; end
        class Callable < ApplicationService
          def call; end
        end
      end
    RUBY
  end

  it "handles cyclic unresolved inheritance" do
    expect_no_offenses(<<~RUBY)
      class First < Second; end
      class Second < First
        def call; end
      end
    RUBY
  end

  context "with a custom base class" do
    let(:cop_config) { { "ServiceBaseClasses" => ["MyApp::BaseService"] } }

    it "checks subclasses of the configured base" do
      expect_offense(<<~RUBY)
        class FetchTickets < MyApp::BaseService
          def call; end
              ^^^^ Operandi/ReservedMethodName: `call` is reserved for Operandi internals. Use `run` or a named step instead.
        end
      RUBY
    end
  end
end
