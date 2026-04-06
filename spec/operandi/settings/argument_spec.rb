# frozen_string_literal: true

RSpec.describe Operandi::Settings::Argument do
  describe "type validation" do
    describe "with boolean type" do
      it "accepts true" do
        service = WithMultipleTypes.run(value: "test", flag: true)
        expect(service.flag).to be(true)
      end

      it "accepts false" do
        service = WithMultipleTypes.run(value: "test", flag: false)
        expect(service.flag).to be(false)
      end

      it "rejects string when type is boolean" do
        expect { WithMultipleTypes.run(value: "test", flag: "true") }
          .to raise_error(Operandi::ArgTypeError, /must be TrueClass or FalseClass/)
      end

      it "rejects integer when type is boolean" do
        expect { WithMultipleTypes.run(value: "test", flag: 1) }
          .to raise_error(Operandi::ArgTypeError, /must be TrueClass or FalseClass/)
      end
    end

    describe "with Hash type" do
      it "accepts matching type" do
        service = WithMultipleTypes.run(value: "test", data: { key: "value" })
        expect(service.data).to eq({ key: "value" })
      end

      it "rejects non-matching type" do
        expect { WithMultipleTypes.run(value: "test", data: "not a hash") }
          .to raise_error(Operandi::ArgTypeError, /(must be|expected).*(Hash|T::Hash)/)
      end
    end

    describe "with multiple types (array)" do
      it "accepts String" do
        service = WithMultipleTypes.run(value: "hello")
        expect(service.value).to eq("hello")
      end

      it "accepts Integer" do
        service = WithMultipleTypes.run(value: 42)
        expect(service.value).to eq(42)
      end

      it "rejects other types" do
        expect { WithMultipleTypes.run(value: 3.14) }
          .to raise_error(Operandi::ArgTypeError, /(must be|expected) (String or Integer|T\.any)/)
      end

      it "rejects nil when not optional" do
        expect { WithMultipleTypes.run(value: nil) }
          .to raise_error(Operandi::ArgTypeError)
      end
    end

    describe "with Class type" do
      it "accepts instances of the class" do
        user = User.create!(name: "Test")
        product = Product.create!(name: "Test", price: 100)
        service = Product::AddToCart.run(current_user: user, product: product)
        expect(service.current_user).to eq(user)
      end

      it "rejects instances of other classes" do
        product = Product.create!(name: "Test", price: 100)
        expect { Product::AddToCart.run(current_user: "not a user", product: product) }
          .to raise_error(Operandi::ArgTypeError, /(must be|expected) User/)
      end
    end

    describe "with optional arguments" do
      it "allows nil when optional: true" do
        service = WithMultipleTypes.run(value: "test", flag: nil)
        expect(service.flag).to be_nil
      end

      it "allows missing optional arguments" do
        service = WithMultipleTypes.run(value: "test")
        expect(service.flag).to be_nil
        expect(service.data).to be_nil
      end
    end
  end

  describe "generated methods" do
    let(:user) { User.create!(name: "Test") }
    let(:product) { Product.create!(name: "Test", price: 100) }
    let(:service) { Product::AddToCart.run(current_user: user, product: product) }

    describe "getter method" do
      it "returns the argument value" do
        expect(service.current_user).to eq(user)
      end
    end

    describe "boolean method" do
      it "returns true for truthy values" do
        expect(service.current_user?).to be(true)
      end

      it "returns false for nil" do
        s = WithMultipleTypes.run(value: "test")
        expect(s.flag?).to be(false)
      end
    end

    describe "setter method" do
      it "is private" do
        expect(service.private_methods).to include(:current_user=)
      end
    end
  end

  describe "default values" do
    it "uses default value when argument not provided" do
      service = WithConditions.run
      expect(service.add_c).to be(false)
    end

    it "uses Proc default evaluated in instance context" do
      user = User.create!(name: "Test")
      product = Product.create!(name: "Test", price: 100)
      service = Product::AddToCart.run(current_user: user, product: product)
      expect(service.arg[:test_default]).to eq(product)
    end

    it "overrides default when argument provided" do
      service = WithConditions.run(add_c: true)
      expect(service.add_c).to be(true)
    end
  end

  describe "context arguments" do
    it "passes context arguments to child services" do
      user = User.create!(name: "Test")
      product = Product.create!(name: "Test", price: 100)
      service = Product::AddToCart.run(current_user: user, product: product)
      # The order is created via Order::Create.with(self) which receives context args
      expect(service).to be_successful
      expect(service.order).to be_persisted
    end
  end
end
