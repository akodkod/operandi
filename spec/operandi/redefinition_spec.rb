# frozen_string_literal: true

RSpec.describe WithRedefinitionBase do # rubocop:disable RSpec/SpecFilePathFormat
  describe "argument type redefinition" do
    it "parent rejects Symbol when type is String" do
      expect { described_class.run(name: :symbol_name) }
        .to raise_error(Operandi::ArgTypeError, /(must be|expected) String/)
    end

    it "parent accepts String" do
      service = described_class.run(name: "string_name")
      expect(service).to be_successful
      expect(service.result).to eq("Base: string_name")
    end

    it "child accepts String when redefined to multiple types" do
      service = WithRedefinedArgTypes.run(name: "string_name", options: {})
      expect(service).to be_successful
      expect(service.result).to eq("Child: string_name")
    end

    it "child accepts Symbol when redefined to multiple types" do
      service = WithRedefinedArgTypes.run(name: :symbol_name, options: {})
      expect(service).to be_successful
      expect(service.result).to eq("Child: symbol_name")
    end

    it "child still rejects other types" do
      expect { WithRedefinedArgTypes.run(name: 123, options: {}) }
        .to raise_error(Operandi::ArgTypeError, /(must be|expected) (String or Symbol|T\.any)/)
    end
  end

  describe "argument optional redefinition" do
    it "parent allows nil for optional argument" do
      service = described_class.run(name: "test")
      expect(service).to be_successful
      expect(service.arg[:options]).to be_nil
    end

    it "child requires argument when redefined as required" do
      expect { WithRedefinedArgTypes.run(name: "test") }
        .to raise_error(Operandi::ArgTypeError, /(must be|expected).*(Hash|T::Hash)/)
    end

    it "child works when required argument provided" do
      service = WithRedefinedArgTypes.run(name: "test", options: { key: "value" })
      expect(service).to be_successful
      expect(service.data[:options]).to eq({ key: "value" })
    end
  end

  describe "argument default redefinition" do
    it "parent uses default 10" do
      service = described_class.run(name: "test")
      expect(service.data[:count]).to eq(10)
    end

    it "child uses redefined default 5" do
      service = WithRedefinedArgTypes.run(name: "test", options: {})
      expect(service.data[:count]).to eq(5)
    end

    it "another child uses redefined default 100" do
      service = WithRedefinedDefaults.run(name: "test")
      expect(service.arg[:count]).to eq(100)
    end

    it "still allows overriding with provided value" do
      service = WithRedefinedDefaults.run(name: "test", count: 42)
      expect(service.arg[:count]).to eq(42)
    end
  end

  describe "output type redefinition" do
    it "parent validates String type" do
      service = described_class.run(name: "test")
      expect(service.result).to eq("Base: test")
      expect(service.result).to be_a(String)
    end

    it "child can return Symbol when redefined to multiple types" do
      service = WithRedefinedOutputTypes.run(name: "test")
      expect(service).to be_successful
      expect(service.result).to eq(:child_result)
      expect(service.result).to be_a(Symbol)
    end
  end

  describe "output optional redefinition" do
    it "parent has default for data output" do
      setting = described_class.outputs[:data]
      expect(setting.default).to eq({})
    end

    it "child allows nil when redefined as optional" do
      service = WithRedefinedOutputTypes.run(name: "test")
      expect(service).to be_successful
      expect(service.data).to be_nil
    end

    it "child requires status when redefined as required" do
      service = WithRedefinedOutputTypes.run(name: "test")
      expect(service.status).to eq(:success)
    end
  end

  describe "output default redefinition" do
    it "parent uses empty hash default" do
      setting = described_class.outputs[:data]
      expect(setting.default).to eq({})
    end

    it "child setting uses new default" do
      setting = WithRedefinedDefaults.outputs[:data]
      expect(setting.default).to eq({ initialized: true })
    end

    it "child service uses new default when not set" do
      service = WithRedefinedDefaults.run(name: "test")
      expect(service.output[:data]).to eq({ initialized: true })
    end
  end

  describe "multi-level inheritance" do
    it "grandchild has arguments from all ancestors" do
      args = WithRedefinedGrandchild.arguments
      expect(args.keys).to include(:name, :count, :options, :extra)
    end

    it "grandchild has outputs from all ancestors" do
      outputs = WithRedefinedGrandchild.outputs
      expect(outputs.keys).to include(:result, :data, :status, :extra_output)
    end

    it "grandchild can redefine arguments again" do
      expect { WithRedefinedGrandchild.run(name: :symbol, options: {}) }
        .to raise_error(Operandi::ArgTypeError, /(must be|expected) String/)
    end

    it "grandchild can add new arguments" do
      service = WithRedefinedGrandchild.run(name: "test", options: {}, extra: "extra_value")
      expect(service).to be_successful
      expect(service.data[:extra]).to eq("extra_value")
    end

    it "grandchild can add new outputs" do
      service = WithRedefinedGrandchild.run(name: "test", options: {}, extra: "extra_value")
      expect(service.extra_output).to eq("extra_value")
    end

    it "grandchild inherits redefined defaults from parent" do
      service = WithRedefinedGrandchild.run(name: "test", options: {})
      expect(service.arg[:count]).to eq(5)
    end
  end

  describe "remove_arg" do
    it "removes an argument from the service" do
      test_class = Class.new(ApplicationService) do
        arg :name, type: String
        arg :email, type: String
        step :process

        private

        def process
          # no-op
        end
      end

      expect(test_class.arguments.keys).to include(:name, :email)

      test_class.remove_arg(:email)

      expect(test_class.arguments.keys).to include(:name)
      expect(test_class.arguments.keys).not_to include(:email)
    end
  end

  describe "remove_output" do
    it "removes an output from the service" do
      test_class = Class.new(ApplicationService) do
        output :result, type: String
        output :metadata, type: Hash
        step :process

        private

        def process
          self.result = "done"
          self.metadata = {}
        end
      end

      expect(test_class.outputs.keys).to include(:result, :metadata)

      test_class.remove_output(:metadata)

      expect(test_class.outputs.keys).to include(:result)
      expect(test_class.outputs.keys).not_to include(:metadata)
    end
  end

  describe "settings reflection" do
    it "child class has its own argument settings" do
      parent_count = described_class.arguments[:count]
      child_count = WithRedefinedArgTypes.arguments[:count]

      expect(parent_count.default).to eq(10)
      expect(child_count.default).to eq(5)

      expect(parent_count.optional).to be_falsey
      expect(child_count.optional).to be(true)
    end

    it "child class has its own output settings" do
      parent_data = described_class.outputs[:data]
      child_data = WithRedefinedOutputTypes.outputs[:data]

      expect(parent_data.default).to eq({})
      expect(parent_data.optional).to be_falsey
      expect(child_data.optional).to be(true)
    end

    it "redefinition in child does not affect parent" do
      WithRedefinedArgTypes.run(name: :symbol, options: {})

      expect { described_class.run(name: :symbol) }
        .to raise_error(Operandi::ArgTypeError, /(must be|expected) String/)
    end

    it "each class maintains independent settings" do
      expect(described_class.arguments.object_id)
        .not_to eq(WithRedefinedArgTypes.arguments.object_id)

      expect(described_class.outputs.object_id)
        .not_to eq(WithRedefinedOutputTypes.outputs.object_id)
    end
  end
end
