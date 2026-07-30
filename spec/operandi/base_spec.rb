# frozen_string_literal: true

RSpec.describe Operandi::Base do
  describe "#success?" do
    context "when no errors" do
      let(:service) { WithConditions.run }

      it { expect(service.success?).to be(true) }
    end

    context "when there are errors" do
      let(:service) { WithConditions.with(use_transactions: false).run(fake_error: true) }

      it { expect(service.success?).to be(false) }
    end
  end

  describe "#failed?" do
    context "when no errors" do
      let(:service) { WithConditions.run }

      it { expect(service.failed?).to be(false) }
    end

    context "when there are errors" do
      let(:service) { WithConditions.with(use_transactions: false).run(fake_error: true) }

      it { expect(service.failed?).to be(true) }
    end
  end

  describe "#errors?" do
    context "when no errors" do
      let(:service) { WithConditions.run }

      it { expect(service.errors?).to be(false) }
    end

    context "when there are errors" do
      let(:service) { WithConditions.with(use_transactions: false).run(fake_error: true) }

      it { expect(service.errors?).to be(true) }
    end
  end

  describe "#warnings?" do
    context "when no warnings" do
      let(:service) { WithConditions.run }

      it { expect(service.warnings?).to be(false) }
    end

    context "when there are warnings" do
      let(:service) { WithConditions.with(use_transactions: false).run(fake_error: true) }

      it { expect(service.warnings?).to be(true) }
    end
  end

  describe "#stop!" do
    let(:service) { WithDone.run(add_c: true) }

    it "stops execution of subsequent steps" do
      expect(service.word).to eq("ab")
    end

    it "does not expose the removed done! alias" do
      expect(service).not_to respond_to(:done!)
    end
  end

  describe "#stopped?" do
    let(:service) { WithDone.run }

    it "returns true after stop! is called" do
      expect(service.stopped?).to be(true)
    end

    it "does not expose the removed done? alias" do
      expect(service).not_to respond_to(:done?)
    end
  end

  describe "#stop_immediately!" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        output :word, type: String, default: ""
        output :after_stop_ran, type: [TrueClass, FalseClass], default: false

        step :letter_a
        step :letter_b
        step :letter_c
        step :cleanup, always: true

        private

        def letter_a
          self.word += "a"
        end

        def letter_b
          self.word += "b"
          stop_immediately!
          self.word += "!" # This should NOT run
        end

        def letter_c
          self.word += "c" # This should NOT run
        end

        def cleanup
          self.after_stop_ran = true
        end
      end
    end

    it "stops execution immediately within the current step" do
      service = service_class.run
      expect(service.word).to eq("ab")
    end

    it "sets stopped? to true" do
      service = service_class.run
      expect(service.stopped?).to be(true)
    end

    it "skips remaining steps" do
      service = service_class.run
      expect(service.word).not_to include("c")
    end

    it "does not run always steps when stop_immediately! is called" do
      service = service_class.run
      expect(service.after_stop_ran).to be(false)
    end

    it "maintains success state (no errors)" do
      service = service_class.run
      expect(service.success?).to be(true)
    end

    context "with database transaction" do
      let(:service_with_db) do
        Class.new(Operandi::Base) do
          config use_transactions: true

          arg :name, type: String

          step :create_user
          step :stop_early
          step :should_not_run

          private

          def create_user
            User.create!(name: name)
          end

          def stop_early
            stop_immediately!
          end

          def should_not_run
            raise "This should never execute"
          end
        end
      end

      it "does not rollback database changes" do
        expect do
          service_with_db.run(name: "stop_immediately_test_user")
        end.to change(User, :count).by(1)

        expect(User.exists?(name: "stop_immediately_test_user")).to be(true)
      end
    end
  end

  describe "#fail!" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        config use_transactions: false

        output :result, type: String, default: ""

        step :step_one
        step :step_two

        private

        def step_one
          fail!("Something went wrong")
          self.result += "a"
        end

        def step_two
          self.result += "b"
        end
      end
    end

    it "adds error to :base key" do
      service = service_class.run
      expect(service.errors[:base]).to include(have_attributes(text: "Something went wrong"))
    end

    it "marks service as failed" do
      service = service_class.run
      expect(service.failed?).to be(true)
    end

    it "continues executing code within the same step" do
      service = service_class.run
      expect(service.result).to include("a")
    end

    it "stops subsequent steps by default (break_on_add)" do
      service = service_class.run
      expect(service.result).not_to include("b")
    end
  end

  describe "#fail_immediately!" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        output :word, type: String, default: ""
        output :after_fail_ran, type: [TrueClass, FalseClass], default: false

        step :letter_a
        step :letter_b
        step :letter_c
        step :cleanup, always: true

        private

        def letter_a
          self.word += "a"
        end

        def letter_b
          self.word += "b"
          fail_immediately!("Critical error")
          self.word += "!" # This should NOT run
        end

        def letter_c
          self.word += "c" # This should NOT run
        end

        def cleanup
          self.after_fail_ran = true
        end
      end
    end

    it "adds error to :base key" do
      service = service_class.run
      expect(service.errors[:base]).to include(have_attributes(text: "Critical error"))
    end

    it "marks service as failed" do
      service = service_class.run
      expect(service.failed?).to be(true)
    end

    it "stops execution immediately within the current step" do
      service = service_class.run
      expect(service.word).to eq("ab")
    end

    it "sets stopped? to false" do
      service = service_class.run
      expect(service.stopped?).to be(false)
    end

    it "skips remaining steps" do
      service = service_class.run
      expect(service.word).not_to include("c")
    end

    it "runs always steps when fail_immediately! is called" do
      service = service_class.run
      expect(service.after_fail_ran).to be(true)
    end

    context "with database transaction" do
      let(:service_with_db) do
        Class.new(Operandi::Base) do
          config use_transactions: true

          arg :name, type: String

          step :create_user
          step :fail_step
          step :should_not_run

          private

          def create_user
            User.create!(name: name)
          end

          def fail_step
            fail_immediately!("Critical failure")
          end

          def should_not_run
            raise "This should never execute"
          end
        end
      end

      it "rolls back database changes" do
        expect do
          service_with_db.run(name: "fail_immediately_test_user")
        end.not_to change(User, :count)

        expect(User.exists?(name: "fail_immediately_test_user")).to be(false)
      end
    end
  end

  describe "exception handling" do
    context "when a step raises an exception" do
      it "still runs steps with always: true" do
        expect { WithException.run }.to raise_error(StandardError, "Something went wrong!")
      end

      it "runs always steps before re-raising" do
        service = WithException.new
        expect { service.call }.to raise_error(StandardError)
        expect(service.always_step_ran).to be(true)
      end
    end
  end

  describe ".run" do
    it "creates and calls the service" do
      service = WithConditions.run
      expect(service).to be_a(WithConditions)
      expect(service.word).to eq("ab")
    end
  end

  describe ".run!" do
    context "when service succeeds" do
      it "returns the service" do
        service = WithConditions.run!
        expect(service).to be_successful
      end
    end

    context "when service fails" do
      it "raises RuntimeError with the service instance" do
        expect { WithClassConfig.run! }.to raise_error(Operandi::RuntimeError) { |error|
          expect(error.service).to be_an_instance_of(WithClassConfig)
        }
      end
    end
  end

  describe ".with" do
    context "with config hash" do
      it "applies config to service" do
        service = WithConditions.with(use_transactions: false).run(fake_error: true)
        expect(service.failed?).to be(true)
      end
    end

    context "with parent service" do
      it "copies context arguments from parent" do
        user = User.create!(name: "Test User")
        product = Product.create!(name: "Test Product", price: 100)
        service = Product::AddToCart.run(current_user: user, product: product)
        # current_user is passed to Order::Create via .with(self) which passes context args
        expect(service).to be_successful
        expect(service.order).to be_persisted
      end
    end

    context "with invalid parent service" do
      it "raises ArgTypeError with the child service class" do
        expect { WithConditions.with(Object.new).run }.to raise_error(Operandi::ArgTypeError) { |error|
          expect(error.service_class).to equal(WithConditions)
        }
      end
    end
  end

  describe ".config" do
    it "sets class-level config" do
      expect(WithClassConfig.class_config).to eq({ raise_on_error: true })
    end
  end

  describe "outputs" do
    let(:service) { WithConditions.run }

    it "provides access via method" do
      expect(service.word).to eq("ab")
    end

    it "provides access via outputs collection" do
      expect(service.output[:word]).to eq("ab")
    end

    it "provides boolean check method" do
      expect(service.word?).to be(true)
    end
  end

  describe "arguments" do
    let(:service) { Product::AddToCart.run(current_user: user, product: product) }
    let(:user) { User.create!(name: "Test User") }
    let(:product) { Product.create!(name: "Test Product", price: 100) }

    it "provides access via method" do
      expect(service.current_user).to eq(user)
    end

    it "provides access via arg collection" do
      expect(service.arg[:current_user]).to eq(user)
    end

    it "provides boolean check method" do
      expect(service.current_user?).to be(true)
    end

    it "allows setting via collection" do
      service.arg[:quantity] = 10
      expect(service.arg[:quantity]).to eq(10)
    end
  end

  describe "Proc defaults" do
    let(:product) { Product.create!(name: "Test", price: 100) }
    let(:user) { User.create!(name: "Test User") }

    it "evaluates Proc defaults in instance context" do
      service = Product::AddToCart.run(current_user: user, product: product)
      # test_default has default: -> { product }
      expect(service.arg[:test_default]).to eq(product)
    end
  end
end
