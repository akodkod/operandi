# frozen_string_literal: true

RSpec.describe Operandi::RuntimeError do
  let(:service) { Class.new(Operandi::Base).new }
  let(:error) { described_class.new("Something failed", service: service) }

  it "inherits from Operandi::Error" do
    expect(described_class).to be < Operandi::Error
  end

  it "preserves the error message" do
    expect(error.message).to eq("Something failed")
  end

  it "exposes the service instance" do
    expect(error.service).to equal(service)
  end

  it "requires a service" do
    expect { described_class.new("Something failed") }.to raise_error(ArgumentError)
    expect do
      described_class.new("Something failed", service: nil)
    end.to raise_error(ArgumentError, "service is required")
    expect do
      described_class.new("Something failed", service: Object.new)
    end.to raise_error(ArgumentError, "service must be an Operandi::Base instance")
  end

  it "can still be rescued as Operandi::Error" do
    expect { raise error }.to raise_error(Operandi::Error)
  end
end

RSpec.describe Operandi::ArgTypeError do
  let(:service_class) { Class.new(Operandi::Base) }
  let(:error) { described_class.new("Invalid argument", service_class: service_class) }

  it "inherits from Operandi::Error but not Operandi::RuntimeError" do
    expect(described_class).to be < Operandi::Error
    expect(described_class).not_to be < Operandi::RuntimeError
  end

  it "preserves the error message" do
    expect(error.message).to eq("Invalid argument")
  end

  it "exposes the service class" do
    expect(error.service_class).to equal(service_class)
  end

  it "requires an Operandi::Base subclass" do
    expect { described_class.new("Invalid argument") }.to raise_error(ArgumentError)
    expect do
      described_class.new("Invalid argument", service_class: nil)
    end.to raise_error(ArgumentError, "service_class is required")
    expect do
      described_class.new("Invalid argument", service_class: String)
    end.to raise_error(ArgumentError, "service_class must be an Operandi::Base subclass")
  end

  it "can still be rescued as Operandi::Error" do
    expect { raise error }.to raise_error(Operandi::Error)
  end
end

RSpec.context Operandi::Error do
  context "with removed exception aliases" do
    it "does not define NoStepError or TwoConditions" do
      expect(Operandi.const_defined?(:NoStepError, false)).to be(false)
      expect(Operandi.const_defined?(:TwoConditions, false)).to be(false)
    end
  end

  context "with two conditions for one step" do
    let(:class_code) do
      <<-RUBY
        class TwoConditions < ApplicationService
          step :hello_world, if: :first, unless: :second
        end
      RUBY
    end

    it do
      expect { eval(class_code) }.to raise_error(Operandi::Error) { |error|
        expect(error).to be_an_instance_of(Operandi::Error)
      }
    end
  end

  context "with `before` and `after` parameters for one step" do
    let(:class_code) do
      <<-RUBY
        class TwoParameters < ApplicationService
          step :hello_world, before: :first, after: :second
        end
      RUBY
    end

    it do
      expect { eval(class_code) }.to raise_error(Operandi::Error) { |error|
        expect(error).to be_an_instance_of(Operandi::Error)
      }
    end
  end

  context "with wrong condition type" do
    let(:class_code) do
      <<-RUBY
        class WrongCondition < ApplicationService
          step :hello_world, if: 42

          private

          def hello_world
            # Hey, whats up?
          end
        end

        WrongCondition.run
      RUBY
    end

    it do
      expect { eval(class_code) }.to raise_error(Operandi::RuntimeError) { |error|
        expect(error.service).to be_an_instance_of(WrongCondition)
      }
    end
  end

  context "with not existed step" do
    let(:class_code) do
      <<-RUBY
        class NoStep < ApplicationService
          step :hello_world
        end

        NoStep.run
      RUBY
    end

    it do
      expect { eval(class_code) }.to raise_error(Operandi::RuntimeError) { |error|
        expect(error.service).to be_an_instance_of(NoStep)
      }
    end
  end

  context "with two same steps" do
    let(:class_code) do
      <<-RUBY
        class TwoSameSteps < ApplicationService
          step :hello_world
          step :hello_world

          private

          def hello_world
            # Hey, whats up?
          end
        end

        TwoSameSteps.run
      RUBY
    end

    it do
      expect { eval(class_code) }.to raise_error(Operandi::Error) { |error|
        expect(error).to be_an_instance_of(Operandi::Error)
      }
    end
  end

  context "with not existed step specified in `after` parameter" do
    let(:class_code) do
      <<-RUBY
        class WithNotExistedStep < ApplicationService
          step :hello_world, after: :i_do_not_exist

          private

          def hello_world
            # Hey, whats up?
          end
        end
      RUBY
    end

    it do
      expect { eval(class_code) }.to raise_error(Operandi::Error) { |error|
        expect(error).to be_an_instance_of(Operandi::Error)
      }
    end
  end

  context "when trying to copy errors from string" do
    let(:class_code) do
      <<-RUBY
        class CopyErrorsFromString < ApplicationService
          step :hello_world

          private

          def hello_world
            self.current_user = User.new
            errors.copy_from("Hello, world!")
          end
        end

        CopyErrorsFromString.run
      RUBY
    end

    it do
      expect { eval(class_code) }.to raise_error(Operandi::RuntimeError) { |error|
        expect(error.service).to be_an_instance_of(CopyErrorsFromString)
      }
    end
  end

  context "when I want 100% coverage" do
    let(:class_code) do
      <<-RUBY
        class WithNotExistedErrorMethod < ApplicationService
          step :hello_world

          private

          def hello_world
            errors.i_do_not_exist
          end
        end

        WithNotExistedErrorMethod.run
      RUBY
    end

    it do
      expect { eval(class_code) }.to raise_error(NoMethodError)
    end
  end

  context "when adding blank error text" do
    let(:class_code_nil) do
      <<-RUBY
        class WithNilErrorText < ApplicationService
          step :add_nil_error

          private

          def add_nil_error
            errors.add(:base, nil)
          end
        end

        WithNilErrorText.run
      RUBY
    end

    let(:class_code_empty) do
      <<-RUBY
        class WithEmptyErrorText < ApplicationService
          step :add_empty_error

          private

          def add_empty_error
            errors.add(:base, "")
          end
        end

        WithEmptyErrorText.run
      RUBY
    end

    let(:class_code_whitespace) do
      <<-RUBY
        class WithWhitespaceErrorText < ApplicationService
          step :add_whitespace_error

          private

          def add_whitespace_error
            errors.add(:base, "   ")
          end
        end

        WithWhitespaceErrorText.run
      RUBY
    end

    it "raises error for nil text" do
      expect { eval(class_code_nil) }
        .to raise_error(Operandi::RuntimeError, "Error must be a non-empty string")
    end

    it "raises error for empty string" do
      expect { eval(class_code_empty) }
        .to raise_error(Operandi::RuntimeError, "Error must be a non-empty string")
    end

    it "raises error for whitespace only" do
      expect { eval(class_code_whitespace) }
        .to raise_error(Operandi::RuntimeError, "Error must be a non-empty string")
    end
  end
end
