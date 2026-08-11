# frozen_string_literal: true

RSpec.describe Operandi::Messages do
  let(:config) { { break_on_add: false, raise_on_add: false, rollback_on_add: false } }
  let(:service) { Class.new(Operandi::Base).new }
  let(:messages) { described_class.new(config, service: service) }

  describe "#initialize" do
    it "requires a service" do
      expect { described_class.new(config) }.to raise_error(ArgumentError, /missing keyword: :service/)
    end
  end

  describe "#add" do
    it "adds a message with key and text" do
      messages.add(:base, "error message")
      expect(messages[:base]).to be_an(Array)
      expect(messages[:base].first.text).to eq("error message")
    end

    it "adds multiple messages for the same key" do
      messages.add(:base, "first error")
      messages.add(:base, "second error")
      expect(messages[:base].size).to eq(2)
    end

    it "adds multiple texts at once" do
      messages.add(:base, ["first error", "second error"])
      expect(messages[:base].size).to eq(2)
    end

    it "accepts Message objects directly" do
      message = Operandi::Message.new(:base, "error text")
      messages.add(:base, message)
      expect(messages[:base].first).to eq(message)
    end

    context "when text is nil" do
      it "raises an error" do
        expect { messages.add(:base, nil) }.to raise_error(Operandi::RuntimeError) { |error|
          expect(error.message).to eq("Error must be a non-empty string")
          expect(error.service).to equal(service)
        }
      end
    end

    context "when text is empty string" do
      it "raises an error" do
        expect { messages.add(:base, "") }
          .to raise_error(Operandi::RuntimeError, "Error must be a non-empty string")
      end
    end

    context "when text is blank whitespace" do
      it "raises an error" do
        expect { messages.add(:base, "   ") }
          .to raise_error(Operandi::RuntimeError, "Error must be a non-empty string")
      end
    end
  end

  describe "#break?" do
    context "when break_on_add is true" do
      let(:config) { { break_on_add: true, raise_on_add: false, rollback_on_add: false } }

      it "returns true after adding a message" do
        expect(messages.break?).to be(false)
        messages.add(:base, "error")
        expect(messages.break?).to be(true)
      end
    end

    context "when break_on_add is false" do
      it "returns false after adding a message" do
        messages.add(:base, "error")
        expect(messages.break?).to be(false)
      end
    end

    context "when break option is passed explicitly" do
      it "breaks when break: true is passed" do
        messages.add(:base, "error", break: true)
        expect(messages.break?).to be(true)
      end

      it "does not break when break: false is passed even if config says break" do
        messages_with_break = described_class.new(
          { break_on_add: true, raise_on_add: false, rollback_on_add: false },
          service: service,
        )
        messages_with_break.add(:base, "error", break: false)
        expect(messages_with_break.break?).to be(false)
      end
    end
  end

  describe "#to_h" do
    it "returns hash with string values" do
      messages.add(:base, "first error")
      messages.add(:name, "name error")
      expect(messages.to_h).to eq({ base: ["first error"], name: ["name error"] })
    end

    it "returns empty hash when no messages" do
      expect(messages.to_h).to eq({})
    end
  end

  describe "#full_messages" do
    it "returns capitalized base messages and humanized attribute messages" do
      messages.add(:base, "request failed")
      messages.add(:first_name, "can't be blank")

      expect(messages.full_messages).to eq(["Request failed", "First name can't be blank"])
    end

    it "returns an empty array when there are no messages" do
      expect(messages.full_messages).to eq([])
    end
  end

  describe "#copy_from" do
    context "with Operandi::Base object" do
      it "copies errors from service" do
        service = WithConditions.with(use_transactions: false).run(fake_error: true)
        messages.copy_from(service)
        expect(messages).to have_key(:base)
      end
    end

    context "with Messages object" do
      it "copies messages from another Messages object" do
        other = described_class.new(config, service: service)
        other.add(:base, "error from other")
        messages.copy_from(other)
        expect(messages[:base].first.text).to eq("error from other")
      end
    end

    context "with Hash" do
      it "copies from hash" do
        messages.copy_from({ base: "hash error", name: ["name error 1", "name error 2"] })
        expect(messages.to_h).to eq({ base: ["hash error"], name: ["name error 1", "name error 2"] })
      end
    end

    context "with unsupported type" do
      it "raises an error" do
        expect { messages.copy_from("string") }
          .to raise_error(Operandi::RuntimeError, /Don't know how to import/)
      end
    end
  end

  describe "#from_record" do
    let(:user) { User.new(name: "") }

    before { user.valid? }

    it "copies errors from ActiveRecord object" do
      messages.from_record(user)
      expect(messages).to have_key(:name)
    end

    it "is an alias for copy_from" do
      messages.from_record(user)
      expect(messages.to_h).to eq({ name: ["can't be blank"] })
    end

    it "accepts options" do
      messages.from_record(user, break: true)
      expect(messages.break?).to be(true)
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for Hash methods" do
      expect(messages.respond_to?(:keys)).to be(true)
      expect(messages.respond_to?(:values)).to be(true)
      expect(messages.respond_to?(:each)).to be(true)
      expect(messages.respond_to?(:size)).to be(true)
      expect(messages.respond_to?(:empty?)).to be(true)
    end

    it "returns false for unknown methods" do
      expect(messages.respond_to?(:unknown_method_xyz)).to be(false)
    end
  end

  describe "#method_missing" do
    it "delegates Hash methods" do
      messages.add(:base, "error")
      expect(messages.keys).to eq([:base])
      expect(messages.values).to be_an(Array)
      expect(messages.size).to eq(1)
      expect(messages.empty?).to be(false)
    end

    it "raises NoMethodError for unknown methods" do
      expect { messages.unknown_method_xyz }.to raise_error(NoMethodError)
    end
  end

  describe "#any?" do
    it "returns false when empty" do
      expect(messages.any?).to be(false)
    end

    it "returns true when has messages" do
      messages.add(:base, "error")
      expect(messages.any?).to be(true)
    end
  end

  describe "raise_on_add behavior" do
    let(:config) { { break_on_add: false, raise_on_add: true, rollback_on_add: false } }

    it "raises RuntimeError with its service context" do
      expect { messages.add(:base, "error text") }
        .to raise_error(Operandi::RuntimeError, "Error text") { |error|
          expect(error.service).to equal(service)
        }
    end
  end
end
