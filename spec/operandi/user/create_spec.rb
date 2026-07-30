# frozen_string_literal: true

RSpec.describe User::Create do
  let(:service) { described_class.run(params: params) }

  context "when args are good" do
    let(:name) { "Andrew Emelianenko" }

    let(:params) do
      {
        user: {
          name: name,
        },
      }
    end

    it { expect(service).to be_successful }
    it { expect(service.user).to be_a(User) }
    it { expect(service.user.name).to eq(name) }
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

  context "when params is empty (run!)" do
    let(:service) { described_class.run!(params: params) }
    let(:params) { {} }

    it { expect { service }.to raise_error(Operandi::RuntimeError) }
  end

  context "when params is empty and context (run!)" do
    let(:service) { described_class.with({ raise_on_error: false }).run!(params: params) }
    let(:params) { {} }

    it { expect { service }.to raise_error(Operandi::RuntimeError) }
  end

  context "when name is absent" do
    let(:service) { described_class.run(params: params) }

    let(:params) do
      {
        user: {
          name: "",
        },
      }
    end

    it { expect(service).to be_failed }
    it { expect(service.errors).to have_key(:name) }
  end
end
