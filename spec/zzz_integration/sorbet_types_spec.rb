# frozen_string_literal: true

# NOTE: This test is in zzz_integration/ to ensure it runs AFTER all other tests.
# Loading sorbet-runtime enables global runtime type checking, which causes the
# Tapioca DSL compiler tests to fail because Sorbet validates the .override
# decorator at runtime. By running these tests last, we avoid affecting other tests.

require "data/services/with_sorbet_types"

RSpec.describe "Sorbet Runtime Types Support" do # rubocop:disable RSpec/DescribeClass
  describe WithSorbetTypes do
    describe "argument validation with Sorbet types" do
      context "with valid string" do
        subject(:service) { described_class.run(name: "John", age: 25) }

        it { is_expected.to be_successful }
        it { expect(service.greeting).to eq("Hello, John!") }
        it { expect(service.user_age).to eq(25) }
      end

      context "with invalid string (integer instead of string)" do
        it "raises ArgTypeError with the service class" do
          expect { described_class.run(name: 123, age: 25) }
            .to raise_error(Operandi::ArgTypeError, /`name`.*expected String.*got Integer/) { |error|
              expect(error.service_class).to equal(described_class)
            }
        end
      end

      context "with invalid integer (string instead of integer)" do
        it "raises ArgTypeError" do
          expect { described_class.run(name: "John", age: "not a number") }
            .to raise_error(Operandi::ArgTypeError, /`age`.*expected Integer.*got String/)
        end
      end

      context "with T.any (union type)" do
        it "accepts string value" do
          service = described_class.run(name: "John", age: 25, status: "active")
          expect(service).to be_successful
          expect(service.full_data[:status]).to eq("active")
        end

        it "accepts symbol value" do
          service = described_class.run(name: "John", age: 25, status: :inactive)
          expect(service).to be_successful
          expect(service.full_data[:status]).to eq(:inactive)
        end

        it "raises error for invalid type" do
          expect { described_class.run(name: "John", age: 25, status: 123) }
            .to raise_error(Operandi::ArgTypeError, /`status`/)
        end
      end

      context "with T.nilable (optional field)" do
        it "accepts nil value" do
          service = described_class.run(name: "John", age: 25, email: nil)
          expect(service).to be_successful
          expect(service.full_data[:email]).to be_nil
        end

        it "accepts string value" do
          service = described_class.run(name: "John", age: 25, email: "john@example.com")
          expect(service).to be_successful
          expect(service.full_data[:email]).to eq("john@example.com")
        end
      end

      context "with T::Array typed array" do
        it "accepts valid array of strings" do
          service = described_class.run(name: "John", age: 25, tags: ["ruby", "rails"])
          expect(service).to be_successful
          expect(service.full_data[:tags]).to eq(["ruby", "rails"])
        end

        # NOTE: Sorbet's T::Array[String] does NOT validate array elements at runtime.
        # Generic type parameters are erased at runtime - it only checks that the value is an Array.
        it "does not validate array elements (Sorbet limitation)" do
          service = described_class.run(name: "John", age: 25, tags: ["ruby", 123])
          expect(service).to be_successful
        end

        it "raises error for non-array value" do
          expect { described_class.run(name: "John", age: 25, tags: "not an array") }
            .to raise_error(Operandi::ArgTypeError, /`tags`/)
        end
      end

      context "with T::Boolean" do
        it "accepts true" do
          service = described_class.run(name: "John", age: 25, active: true)
          expect(service).to be_successful
          expect(service.full_data[:active]).to be(true)
        end

        it "accepts false" do
          service = described_class.run(name: "John", age: 25, active: false)
          expect(service).to be_successful
          expect(service.full_data[:active]).to be(false)
        end

        it "raises error for non-boolean value" do
          expect { described_class.run(name: "John", age: 25, active: "yes") }
            .to raise_error(Operandi::ArgTypeError, /`active`/)
        end
      end

      context "with T::Enum" do
        it "accepts enum values" do
          service = described_class.run(
            name: "John",
            age: 25,
            notification_status: SorbetNotificationStatus::Sent,
          )

          expect(service).to be_successful
          expect(service.notification_status).to eq(SorbetNotificationStatus::Sent)
          expect(service.full_data[:notification_status]).to eq(SorbetNotificationStatus::Sent)
        end

        it "deserializes raw enum values" do
          service = described_class.run(name: "John", age: 25, notification_status: "sent")

          expect(service).to be_successful
          expect(service.notification_status).to eq(SorbetNotificationStatus::Sent)
          expect(service.full_data[:notification_status]).to eq(SorbetNotificationStatus::Sent)
        end

        it "deserializes raw enum defaults" do
          service = described_class.run(name: "John", age: 25)

          expect(service).to be_successful
          expect(service.notification_status).to eq(SorbetNotificationStatus::Queued)
        end

        it "accepts nil for optional enum arguments" do
          service = described_class.run(name: "John", age: 25, optional_notification_status: nil)

          expect(service).to be_successful
          expect(service.optional_notification_status).to be_nil
        end

        it "raises error for invalid raw enum values" do
          expect { described_class.run(name: "John", age: 25, notification_status: "missing") }
            .to raise_error(Operandi::ArgTypeError, /`notification_status`/)
        end
      end
    end

    describe "output validation with Sorbet types" do
      context "with valid outputs" do
        subject(:service) { described_class.run(name: "John", age: 25) }

        it { is_expected.to be_successful }
        it { expect(service.greeting).to be_a(String) }
        it { expect(service.user_age).to be_a(Integer) }
        it { expect(service.full_data).to be_a(Hash) }
      end
    end

    describe "mixing Sorbet types with optional fields" do
      context "when optional field is nil" do
        subject(:service) { described_class.run(name: "John", age: 25) }

        it { is_expected.to be_successful }
        it { expect(service.full_data[:email]).to be_nil }
        it { expect(service.full_data[:tags]).to eq([]) }
      end
    end

    describe "no coercion behavior" do
      # Sorbet runtime types do NOT coerce values, only validate them
      context "when passing a string where integer is expected" do
        it "raises an error instead of coercing" do
          expect { described_class.run(name: "John", age: "30") }
            .to raise_error(Operandi::ArgTypeError, /`age`.*expected Integer/)
        end
      end
    end
  end
end
