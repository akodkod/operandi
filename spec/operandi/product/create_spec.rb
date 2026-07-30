# frozen_string_literal: true

RSpec.describe Product::Create do
  let(:service) { described_class.run(params: params) }

  context "when args are good" do
    let(:name) { "iPhone" }
    let(:price) { 100 }

    let(:params) do
      {
        product: {
          name: name,
          price: price,
        },
      }
    end

    it { expect(service).to be_successful }
    it { expect(service.product).to be_a(Product) }
    it { expect(service.product.name).to eq(name) }
    it { expect(service.product.price).to eq(price) }
  end

  context "when params is wrong" do
    let(:params) { "hey" }

    it { expect { service }.to raise_error(Operandi::ArgTypeError) }
  end

  context "when params is empty" do
    let(:params) { {} }

    it { expect(service).to be_failed }
    it { expect(service.errors).to have_key(:params) }
  end

  context "when params is empty (and raise on error is true)" do
    let(:service) { described_class.with(raise_on_error: true).run(params: params) }
    let(:params) { {} }

    it { expect { service }.to raise_error(Operandi::RuntimeError) }
  end

  context "when name is absent" do
    let(:service) { described_class.run(params: params) }

    let(:params) do
      {
        product: {
          name: "",
          price: nil,
        },
      }
    end

    it { expect(service).to be_failed }
    it { expect(service.errors).to have_key(:name) }
    it { expect(service.errors).to have_key(:price) }
  end
end
