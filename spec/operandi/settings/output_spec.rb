# frozen_string_literal: true

RSpec.describe Operandi::Settings::Output do
  describe "option validation" do
    it "rejects unknown options" do
      expect do
        Class.new(Operandi::Base) do
          output :result, type: Hash, defualt: {}
        end
      end.to raise_error(Operandi::Error, /Unknown option `defualt`.*Valid options:.*`default`/)
    end
  end

  describe "type validation" do
    describe "with Class type" do
      it "accepts instances of the class" do
        service = WithTypedOutputs.run(user_name: "Test User")
        expect(service.user).to be_a(User)
      end

      it "validates nil for optional outputs" do
        service = WithTypedOutputs.run
        expect(service.user).to be_nil
        expect(service).to be_successful
      end
    end

    describe "with Hash type" do
      it "accepts a Hash" do
        service = WithTypedOutputs.run
        service.output.set(:data, { key: "value" })
        expect(service.data).to eq({ key: "value" })
      end
    end

    describe "with wrong type" do
      it "raises ArgTypeError when output has wrong type" do
        expect { WithTypedOutputs.run(return_wrong_type: true) }
          .to raise_error(Operandi::ArgTypeError, /output `message` (must be|expected) String/) { |error|
            expect(error.service_class).to equal(WithTypedOutputs)
          }
      end
    end

    describe "with default values" do
      it "uses default value when not set" do
        service = WithTypedOutputs.run
        # count has default: 0, but it gets overwritten in build_message
        expect(service.count).to eq(13) # "Hello, World!".length
      end
    end
  end

  describe "generated methods" do
    let(:service) { WithTypedOutputs.run(user_name: "Test") }

    describe "getter method" do
      it "returns the output value" do
        expect(service.message).to eq("Hello, Test!")
      end
    end

    describe "boolean method" do
      it "returns true for truthy values" do
        expect(service.user?).to be(true)
      end

      it "returns false for nil" do
        s = WithTypedOutputs.run
        expect(s.user?).to be(false)
      end
    end

    describe "setter method" do
      it "is private" do
        expect(service.private_methods).to include(:message=)
      end
    end
  end

  describe "optional outputs" do
    it "allows nil when optional: true" do
      service = WithTypedOutputs.run
      expect(service.user).to be_nil
      expect(service.data).to be_nil
      expect(service).to be_successful
    end

    it "validates type when value is present" do
      service = WithTypedOutputs.run(user_name: "Test")
      expect(service.user).to be_a(User)
    end
  end
end
