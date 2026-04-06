# frozen_string_literal: true

RSpec.describe Product::AddToCart do
  let(:service) { described_class.run(current_user: current_user, product: product) }

  context "when args are good" do
    let(:current_user) { User.create!(name: "Andrew Emelianenko") }
    let(:product) { Product.create!(name: "Tesla Model X", price: 100_000) }

    it { expect(service).to be_successful }
    it { expect(service.order).to be_a(Order) }
    it { expect(service.order?).to be(true) }
    it { expect(service.order.products).to include(product) }
    it { expect(service.order.total_price).to be(100_000) }
    it { expect(service.output[:order]).to be_a(Order) }
    it { expect { service.arg[:quantity] = 5 }.not_to raise_error }
  end

  context "with quantity" do
    let(:service) { described_class.run(current_user: current_user, product: product, quantity: 2) }
    let(:current_user) { User.create!(name: "Andrew Emelianenko") }
    let(:product) { Product.create!(name: "Tesla Model X", price: 100_000) }

    it { expect(service).to be_successful }
    it { expect(service.order).to be_a(Order) }
    it { expect(service.order.products).to include(product) }
    it { expect(service.order.total_price).to be(200_000) }
  end

  context "when current user is absent" do
    let(:current_user) { nil }
    let(:product) { Product.create!(name: "Tesla Model X", price: 100_000) }

    it { expect { service }.to raise_error(Operandi::ArgTypeError) }
  end

  context "when product is absent" do
    let(:current_user) { User.create!(name: "Andrew Emelianenko") }
    let(:product) { nil }

    it { expect { service }.to raise_error(Operandi::ArgTypeError) }
  end
end
