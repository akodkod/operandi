# frozen_string_literal: true

RSpec.describe WithDoneBypassesAlways do
  it "bypasses always steps when stop! is called" do
    service = described_class.run

    expect(service).to be_successful
    expect(service.trace).to eq([:work, :after_done])
  end
end
