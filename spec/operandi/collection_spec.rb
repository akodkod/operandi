# frozen_string_literal: true

RSpec.describe Operandi::Collection::Base do
  describe "#[]" do
    let(:service) { WithConditions.run }

    it "returns value for key" do
      expect(service.arg[:add_c]).to be(false)
    end

    it "returns nil for missing key" do
      expect(service.arg[:nonexistent]).to be_nil
    end
  end

  describe "#[]=" do
    let(:service) { WithConditions.run }

    it "sets value for key" do
      service.arg[:custom_key] = "custom_value"
      expect(service.arg[:custom_key]).to eq("custom_value")
    end
  end

  describe "#get" do
    let(:service) { WithConditions.run }

    it "returns value for key" do
      expect(service.arg.get(:add_c)).to be(false)
    end
  end

  describe "#set" do
    let(:service) { WithConditions.run }

    it "sets value for key" do
      service.arg.set(:custom, "value")
      expect(service.arg.get(:custom)).to eq("value")
    end
  end

  describe "#key?" do
    let(:service) { WithConditions.run }

    it "returns true for existing key" do
      expect(service.arg.key?(:add_c)).to be(true)
    end

    it "returns false for missing key" do
      expect(service.arg.key?(:nonexistent)).to be(false)
    end
  end

  describe "#to_h" do
    let(:service) { WithConditions.run }

    it "returns hash representation" do
      hash = service.arg.to_h
      expect(hash).to be_a(Hash)
      expect(hash).to include(:add_c, :do_not_add_d)
    end
  end

  describe "#load_defaults" do
    context "with static defaults" do
      let(:service) { WithConditions.new }

      before { service.arg.load_defaults }

      it "loads default values" do
        expect(service.add_c).to be(false)
        expect(service.do_not_add_d).to be(true)
      end
    end

    context "with Proc defaults" do
      let(:user) { User.create!(name: "Test") }
      let(:product) { Product.create!(name: "Test", price: 100) }
      let(:service) { Product::AddToCart.new(current_user: user, product: product) }

      before do
        service.arg.load_defaults
      end

      it "evaluates Proc in instance context" do
        expect(service.arg[:test_default]).to eq(product)
      end
    end

    context "with complex defaults" do
      it "deep dups default values to avoid mutations" do
        # Run two services with array/hash defaults
        service1 = CreateService.new(params: {})
        service2 = CreateService.new(params: {})

        service1.output.load_defaults
        service2.output.load_defaults

        # Modify one service's default
        service1.output[:data][:modified] = true

        # The other should be unaffected
        expect(service2.output[:data]).not_to have_key(:modified)
      end
    end
  end

  describe "initialization with non-Hash" do
    it "raises ArgumentError when passing positional argument to run" do
      # With **kwargs, Ruby raises ArgumentError for positional arguments
      expect { WithConditions.run("not a hash") }.to raise_error(ArgumentError)
    end

    it "raises ArgTypeError when storage is not a Hash" do
      service = WithConditions.new
      expect do
        described_class.new(service, Operandi::CollectionTypes::ARGUMENTS, "not a hash")
      end.to raise_error(Operandi::ArgTypeError, /must be a Hash/)
    end
  end

  describe "initialization with invalid collection_type" do
    it "raises ArgumentError for invalid collection type" do
      service = WithConditions.new
      expect do
        described_class.new(service, :invalid_type)
      end.to raise_error(ArgumentError, /collection_type must be one of/)
    end
  end

  describe "#method_missing" do
    let(:service) { WithConditions.run }

    it "returns value for existing key" do
      expect(service.arg.add_c).to be(false)
    end

    it "returns nil for defined but unset key" do
      expect(service.arg.do_not_add_d).to be(true)
    end

    it "raises NoMethodError for undefined key" do
      expect { service.arg.undefined_key }.to raise_error(NoMethodError)
    end
  end

  describe "#respond_to_missing?" do
    let(:service) { WithConditions.run }

    it "returns true for existing key in storage" do
      expect(service.arg.respond_to?(:add_c)).to be(true)
    end

    it "returns true for defined key in settings" do
      expect(service.arg.respond_to?(:do_not_add_d)).to be(true)
    end

    it "returns false for undefined key" do
      expect(service.arg.respond_to?(:undefined_key)).to be(false)
    end

    it "works with output collection" do
      expect(service.output.respond_to?(:word)).to be(true)
      expect(service.output.respond_to?(:nonexistent)).to be(false)
    end
  end
end

RSpec.describe Operandi::Collection::Arguments do
  describe "#extend_with_context" do
    let(:user) { User.create!(name: "Test") }
    let(:product) { Product.create!(name: "Test", price: 100) }

    it "extends args with context arguments from parent" do
      # ApplicationService has current_user as context: true
      parent = ApplicationService.new(current_user: user)
      parent.arg.load_defaults

      args = parent.arg.dup.extend_with_context({})
      expect(args[:current_user]).to eq(user)
    end

    it "does not override existing args" do
      parent = ApplicationService.new(current_user: user)
      parent.arg.load_defaults

      other_user = User.create!(name: "Other")
      args = parent.arg.dup.extend_with_context({ current_user: other_user })
      expect(args[:current_user]).to eq(other_user)
    end
  end

  describe "#validate!" do
    context "with valid types" do
      it "does not raise" do
        expect { WithConditions.run(add_c: true) }.not_to raise_error
      end
    end

    context "with invalid types" do
      it "raises ArgTypeError" do
        expect { WithMultipleTypes.run(value: 3.14) }
          .to raise_error(Operandi::ArgTypeError)
      end
    end

    context "with optional nil values" do
      it "skips validation" do
        expect { WithMultipleTypes.run(value: "test", flag: nil) }.not_to raise_error
      end
    end
  end

  describe "deprecated #arguments alias" do
    let(:service) { WithConditions.run }

    it "returns the same object as #arg" do
      expect(service.arguments).to be(service.arg)
    end

    it "emits a deprecation warning" do
      expect { service.arguments }.to output(/DEPRECATION.*Use `arg` instead/).to_stderr
    end
  end
end

RSpec.describe Operandi::Collection::Outputs do
  describe "#load_defaults" do
    let(:service) { WithConditions.new }

    before { service.output.load_defaults }

    it "loads default output values" do
      expect(service.word).to eq("")
    end
  end

  describe "accessor methods" do
    let(:service) { WithConditions.run }

    it "provides getter" do
      expect(service.word).to eq("ab")
    end

    it "provides boolean check" do
      expect(service.word?).to be(true)
    end
  end

  describe "deprecated #outputs alias" do
    let(:service) { WithConditions.run }

    it "returns the same object as #output" do
      expect(service.outputs).to be(service.output)
    end

    it "emits a deprecation warning" do
      expect { service.outputs }.to output(/DEPRECATION.*Use `output` instead/).to_stderr
    end
  end
end
