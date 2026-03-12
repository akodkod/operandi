# frozen_string_literal: true

RSpec.describe Operandi::Base, ".config DSL" do # rubocop:disable RSpec/SpecFilePathFormat
  describe "raise_on_error: true" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        config raise_on_error: true

        step :add_error

        private

        def add_error
          errors.add(:base, "This is an error")
        end
      end
    end

    it "raises Operandi::Error when an error is added" do
      expect { service_class.run }.to raise_error(Operandi::Error)
    end
  end

  describe "break_on_error: false" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        config break_on_error: false, use_transactions: false

        output :word, type: String, default: ""

        step :step_one
        step :step_two
        step :step_three

        private

        def step_one
          self.word += "a"
        end

        def step_two
          errors.add(:base, "something went wrong")
          self.word += "b"
        end

        def step_three
          self.word += "c"
        end
      end
    end

    it "continues executing steps after an error is added" do
      service = service_class.run
      expect(service.word).to eq("abc")
    end

    it "still records the error" do
      service = service_class.run
      expect(service.errors?).to be(true)
    end
  end

  describe "rollback_on_error: false with use_transactions: true" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        config rollback_on_error: false, use_transactions: true

        arg :name, type: String

        step :create_user
        step :add_error

        private

        def create_user
          User.create!(name: name)
        end

        def add_error
          errors.add(:base, "something went wrong")
        end
      end
    end

    it "persists DB changes even when an error occurs" do
      expect do
        service_class.run(name: "rollback_test_user")
      end.to change(User, :count).by(1)
    end
  end

  describe "use_transactions: false" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        config use_transactions: false

        arg :name, type: String

        step :create_user
        step :add_error

        private

        def create_user
          User.create!(name: name)
        end

        def add_error
          errors.add(:base, "something went wrong")
        end
      end
    end

    it "persists DB changes even when an error occurs" do
      expect do
        service_class.run(name: "no_tx_test_user")
      end.to change(User, :count).by(1)
    end
  end

  describe "break_on_warning: true" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        config break_on_warning: true, use_transactions: false

        output :word, type: String, default: ""

        step :step_one
        step :step_two
        step :step_three

        private

        def step_one
          self.word += "a"
        end

        def step_two
          warnings.add(:base, "a warning")
          self.word += "b"
        end

        def step_three
          self.word += "c"
        end
      end
    end

    it "stops executing steps after a warning is added" do
      service = service_class.run
      expect(service.word).to eq("ab")
    end

    it "records the warning" do
      service = service_class.run
      expect(service.warnings?).to be(true)
    end
  end

  describe "raise_on_warning: true" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        config raise_on_warning: true

        step :add_warning

        private

        def add_warning
          warnings.add(:base, "a warning")
        end
      end
    end

    it "raises Operandi::Error when a warning is added" do
      expect { service_class.run }.to raise_error(Operandi::Error)
    end
  end

  describe "rollback_on_warning: true with use_transactions: true" do
    let(:service_class) do
      Class.new(Operandi::Base) do
        config rollback_on_warning: true, use_transactions: true

        arg :name, type: String

        step :create_user
        step :add_warning

        private

        def create_user
          User.create!(name: name)
        end

        def add_warning
          warnings.add(:base, "a warning")
        end
      end
    end

    it "rolls back DB changes when a warning occurs" do
      expect do
        service_class.run(name: "rollback_warning_user")
      end.not_to change(User, :count)
    end
  end

  describe "load_errors: false" do
    let(:child_class) do
      Class.new(Operandi::Base) do
        config load_errors: false, use_transactions: false

        step :add_error

        private

        def add_error
          errors.add(:base, "child error")
        end
      end
    end

    let(:parent_class) do
      child = child_class
      Class.new(Operandi::Base) do
        config use_transactions: false

        output :child_result, type: Operandi::Base

        step :run_child

        define_method(:run_child) do
          self.child_result = child.with(self).run
        end
      end
    end

    it "does not copy child errors to parent service" do
      service = parent_class.run
      expect(service.errors?).to be(false)
    end

    it "child still has its own errors" do
      service = parent_class.run
      expect(service.child_result.errors?).to be(true)
    end
  end

  describe "load_warnings: false" do
    let(:child_class) do
      Class.new(Operandi::Base) do
        config load_warnings: false, use_transactions: false

        step :add_warning

        private

        def add_warning
          warnings.add(:base, "child warning")
        end
      end
    end

    let(:parent_class) do
      child = child_class
      Class.new(Operandi::Base) do
        config use_transactions: false

        output :child_result, type: Operandi::Base

        step :run_child

        define_method(:run_child) do
          self.child_result = child.with(self).run
        end
      end
    end

    it "does not copy child warnings to parent service" do
      service = parent_class.run
      expect(service.warnings?).to be(false)
    end

    it "child still has its own warnings" do
      service = parent_class.run
      expect(service.child_result.warnings?).to be(true)
    end
  end

  describe "config inheritance" do
    let(:parent_class) do
      Class.new(Operandi::Base) do
        config raise_on_error: true, break_on_warning: true
      end
    end

    it "subclass does not inherit parent's class_config by default" do
      subclass = Class.new(parent_class)
      expect(subclass.class_config).to be_nil
    end

    it "subclass can define its own config independently" do
      subclass = Class.new(parent_class) do
        config raise_on_error: false
      end
      expect(subclass.class_config).to eq({ raise_on_error: false })
    end

    it "parent class_config is applied at runtime via merge chain" do
      # Parent has raise_on_error: true, so running it raises
      parent_class.class_eval do
        step :add_error

        private

        define_method(:add_error) do
          errors.add(:base, "error")
        end
      end
      expect { parent_class.run }.to raise_error(Operandi::Error)
    end
  end

  describe "config precedence: global < class_config < runtime .with()" do
    around do |example|
      original = Operandi.config.break_on_error
      Operandi.config.break_on_error = true
      example.run
    ensure
      Operandi.config.break_on_error = original
    end

    let(:service_class) do
      Class.new(Operandi::Base) do
        config break_on_error: false, use_transactions: false

        output :word, type: String, default: ""

        step :step_one
        step :step_two

        private

        def step_one
          errors.add(:base, "an error")
          self.word += "a"
        end

        def step_two
          self.word += "b"
        end
      end
    end

    it "class_config overrides global config" do
      service = service_class.run
      # Global says break_on_error: true, but class says false, so step_two runs
      expect(service.word).to eq("ab")
    end

    it "runtime .with() overrides class_config" do
      service = service_class.with(break_on_error: true).run
      # Class says break_on_error: false, but runtime says true, so step_two is skipped
      expect(service.word).to eq("a")
    end
  end
end
