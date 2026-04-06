# frozen_string_literal: true

RSpec.describe Operandi::Utils do
  describe ".deep_dup" do
    context "with Hash objects" do
      it "creates independent copy of simple hash" do
        original = { a: 1, b: 2 }
        copy = described_class.deep_dup(original)

        copy[:a] = 999
        expect(original[:a]).to eq(1)
      end

      it "creates independent copy of nested hash" do
        original = { level1: { level2: { level3: "value" } } }
        copy = described_class.deep_dup(original)

        copy[:level1][:level2][:level3] = "modified"
        expect(original[:level1][:level2][:level3]).to eq("value")
      end

      it "handles hash with mixed value types" do
        original = { string: "hello", number: 42, array: [1, 2, 3], nested: { key: "value" } }
        copy = described_class.deep_dup(original)

        copy[:array] << 4
        copy[:nested][:key] = "changed"

        expect(original[:array]).to eq([1, 2, 3])
        expect(original[:nested][:key]).to eq("value")
      end
    end

    context "with Array objects" do
      it "creates independent copy of simple array" do
        original = [1, 2, 3]
        copy = described_class.deep_dup(original)

        copy << 4
        expect(original).to eq([1, 2, 3])
      end

      it "creates independent copy of nested array" do
        original = [[1, 2], [3, 4], [5, 6]]
        copy = described_class.deep_dup(original)

        copy[0] << 99
        expect(original[0]).to eq([1, 2])
      end

      it "creates independent copy of array with hash elements" do
        original = [{ a: 1 }, { b: 2 }]
        copy = described_class.deep_dup(original)

        copy[0][:a] = 999
        expect(original[0][:a]).to eq(1)
      end
    end

    context "with String objects" do
      it "creates independent copy" do
        original = "hello"
        copy = described_class.deep_dup(original)

        copy << " world"
        expect(original).to eq("hello")
      end

      it "handles frozen strings" do
        original = "frozen".freeze # rubocop:disable Style/RedundantFreeze
        copy = described_class.deep_dup(original)

        # Copy should be a new object (different object_id)
        expect(copy).to eq(original)
      end
    end

    context "with immutable objects" do
      it "returns same Integer (immutable)" do
        original = 42
        copy = described_class.deep_dup(original)

        expect(copy).to eq(42)
      end

      it "returns same Symbol (immutable)" do
        original = :my_symbol
        copy = described_class.deep_dup(original)

        expect(copy).to eq(:my_symbol)
      end

      it "returns same nil" do
        expect(described_class.deep_dup(nil)).to be_nil
      end

      it "returns same true" do
        expect(described_class.deep_dup(true)).to be(true)
      end

      it "returns same false" do
        expect(described_class.deep_dup(false)).to be(false)
      end
    end

    context "with objects responding to deep_dup" do
      let(:custom_object) do
        Class.new do
          attr_accessor :value

          def initialize(value)
            @value = value
          end

          def deep_dup
            self.class.new(@value.dup)
          end
        end.new("original")
      end

      it "uses the object's deep_dup method" do
        copy = described_class.deep_dup(custom_object)

        copy.value = "modified"
        expect(custom_object.value).to eq("original")
      end
    end

    context "with objects that cannot be marshalled" do
      let(:non_marshalable_object) do
        Class.new do
          attr_accessor :value

          def initialize(value)
            @value = value
          end

          # Explicitly prevent marshalling
          def _dump(_level)
            raise TypeError, "can't dump"
          end

          def dup
            self.class.new(@value)
          end
        end.new("test")
      end

      it "falls back to dup" do
        copy = described_class.deep_dup(non_marshalable_object)
        expect(copy.value).to eq("test")
        expect(copy).not_to be(non_marshalable_object)
      end
    end

    context "when deep_dup is not available (Marshal fallback)" do
      # Create a marshalable container that doesn't respond to deep_dup
      let(:marshalable_container_class) do
        Class.new do
          attr_accessor :data

          def initialize(data = nil)
            @data = data
          end

          # Explicitly not responding to deep_dup
          def respond_to?(method, include_all = false) # rubocop:disable Style/OptionalBooleanParameter
            return false if method.to_sym == :deep_dup

            super
          end

          def ==(other)
            other.is_a?(self.class) && other.data == @data
          end
        end
      end

      before do
        stub_const("MarshalableContainer", marshalable_container_class)
        allow(Marshal).to receive(:dump).and_call_original
        allow(Marshal).to receive(:load).and_call_original
      end

      it "uses Marshal.load/dump for nested hash" do
        inner_data = { level1: { level2: "value" } }
        original = MarshalableContainer.new(inner_data)

        copy = described_class.deep_dup(original)

        expect(Marshal).to have_received(:dump)
        expect(Marshal).to have_received(:load)
        expect(copy.object_id).not_to eq(original.object_id)
        expect(copy.data.object_id).not_to eq(original.data.object_id)
        copy.data[:level1][:level2] = "modified"
        expect(original.data[:level1][:level2]).to eq("value")
      end

      it "uses Marshal.load/dump for nested array" do
        inner_data = [[1, 2], [3, 4]]
        original = MarshalableContainer.new(inner_data)

        copy = described_class.deep_dup(original)

        expect(Marshal).to have_received(:dump)
        expect(Marshal).to have_received(:load)
        copy.data[0] << 99
        expect(original.data[0]).to eq([1, 2])
      end

      it "uses Marshal.load/dump for complex structures" do
        inner_data = { users: [{ name: "John", tags: ["admin"] }] }
        original = MarshalableContainer.new(inner_data)

        copy = described_class.deep_dup(original)

        expect(Marshal).to have_received(:dump)
        expect(Marshal).to have_received(:load)
        copy.data[:users][0][:name] = "Modified"
        copy.data[:users][0][:tags] << "new"
        expect(original.data[:users][0][:name]).to eq("John")
        expect(original.data[:users][0][:tags]).to eq(["admin"])
      end
    end

    context "when deep_dup is not available and Marshal fails (dup fallback)" do
      let(:object_class) do
        Class.new do
          attr_accessor :value

          def initialize(value)
            @value = value
          end

          def dup
            self.class.new(@value)
          end
        end
      end

      it "falls back to dup when Marshal raises TypeError" do
        original = object_class.new("test_value")

        allow(original).to receive(:respond_to?).and_call_original
        allow(original).to receive(:respond_to?).with(:deep_dup).and_return(false)
        allow(Marshal).to receive(:dump).and_raise(TypeError, "can't dump")

        copy = described_class.deep_dup(original)

        expect(copy).not_to be(original)
        expect(copy.value).to eq("test_value")
      end

      it "creates a shallow copy via dup" do
        inner = { key: "value" }
        original = object_class.new(inner)

        allow(original).to receive(:respond_to?).and_call_original
        allow(original).to receive(:respond_to?).with(:deep_dup).and_return(false)
        allow(Marshal).to receive(:dump).and_raise(TypeError, "can't dump")

        copy = described_class.deep_dup(original)

        # dup creates shallow copy, so inner hash is shared
        expect(copy.value).to be(original.value)
      end
    end

    context "when deep_dup, Marshal, and dup are all unavailable" do
      let(:basic_object_wrapper) do
        # Create an object that doesn't respond to deep_dup or dup
        Class.new do
          attr_reader :value

          def initialize(value)
            @value = value
          end

          # Explicitly make respond_to? return false for dup
          def respond_to?(method, include_all = false) # rubocop:disable Style/OptionalBooleanParameter
            return false if [:dup, :deep_dup].include?(method)

            super
          end
        end
      end

      it "returns the original object when nothing else works" do
        original = basic_object_wrapper.new("immutable_value")

        allow(Marshal).to receive(:dump).and_raise(TypeError, "can't dump")

        copy = described_class.deep_dup(original)

        expect(copy).to be(original)
        expect(copy.value).to eq("immutable_value")
      end
    end

    context "with complex nested structures" do
      let(:original) do
        {
          users: [
            { name: "John", tags: ["admin", "active"], metadata: { created: "2024-01-01" } },
            { name: "Jane", tags: ["user"], metadata: { created: "2024-01-02" } },
          ],
          settings: { notifications: { email: true, sms: false }, features: ["feature1", "feature2"] },
        }
      end

      it "handles deeply nested mixed structures" do
        copy = described_class.deep_dup(original)

        copy[:users][0][:name] = "Modified"
        copy[:users][0][:tags] << "new_tag"
        copy[:users][0][:metadata][:created] = "2025-01-01"
        copy[:settings][:notifications][:email] = false
        copy[:settings][:features] << "feature3"

        expect(original[:users][0][:name]).to eq("John")
        expect(original[:users][0][:tags]).to eq(["admin", "active"])
        expect(original[:users][0][:metadata][:created]).to eq("2024-01-01")
        expect(original[:settings][:notifications][:email]).to be(true)
        expect(original[:settings][:features]).to eq(["feature1", "feature2"])
      end
    end

    context "with empty collections" do
      it "handles empty hash" do
        original = {}
        copy = described_class.deep_dup(original)

        copy[:new_key] = "value"
        expect(original).to eq({})
      end

      it "handles empty array" do
        original = []
        copy = described_class.deep_dup(original)

        copy << "item"
        expect(original).to eq([])
      end
    end

    context "with service defaults integration" do
      it "prevents mutation of default hash values across service instances" do
        service1 = CreateService.new(params: {})
        service2 = CreateService.new(params: {})

        service1.output.load_defaults
        service2.output.load_defaults

        # Modify first service's output
        service1.output[:data][:key] = "value"

        # Second service should have independent copy
        expect(service2.output[:data]).to eq({})
      end
    end
  end
end
