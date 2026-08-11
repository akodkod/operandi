# frozen_string_literal: true

RSpec.describe Operandi::Callbacks do
  describe "service callbacks with symbols" do
    describe "before_service_run" do
      it "is called before the service runs" do
        service = WithCallbacks.run
        expect(service.callback_log.first).to eq(:before_service_run)
      end
    end

    describe "after_service_run" do
      it "is called after the service completes" do
        service = WithCallbacks.run
        expect(service.callback_log).to include(:after_service_run)
      end

      it "is called before success/failure callbacks" do
        service = WithCallbacks.run
        after_index = service.callback_log.index(:after_service_run)
        success_index = service.callback_log.index(:on_service_success)
        expect(after_index).to be < success_index
      end
    end

    describe "on_service_success" do
      context "when service succeeds" do
        it "is called" do
          service = WithCallbacks.run
          expect(service.callback_log).to include(:on_service_success)
        end
      end

      context "when service fails" do
        it "is not called" do
          service = WithCallbacksFailure.with(use_transactions: false).run
          expect(service.callback_log).not_to include(:on_service_success)
        end
      end
    end

    describe "on_service_failure" do
      context "when service fails" do
        it "is called" do
          service = WithCallbacksFailure.with(use_transactions: false).run
          expect(service.callback_log).to include(:on_service_failure)
        end
      end

      context "when service succeeds" do
        it "is not called" do
          service = WithCallbacks.run
          expect(service.callback_log).not_to include(:on_service_failure)
        end
      end
    end
  end

  describe "service callbacks with procs" do
    it "executes proc callbacks" do
      service = WithCallbacksProc.run
      expect(service.callback_log).to include(:before_service_run_proc)
      expect(service.callback_log).to include(:after_service_run_proc)
      expect(service.callback_log).to include(:on_service_success_proc)
    end
  end

  describe "around_service_run" do
    context "with symbol callback" do
      it "wraps the service execution" do
        service = WithAroundCallbacks.run
        expect(service.callback_log).to eq([
          :around_service_before,
          [:around_step_before, :do_work],
          :do_work,
          [:around_step_after, :do_work],
          :around_service_after,
        ])
      end
    end

    context "with proc callback" do
      it "wraps the service execution" do
        service = WithAroundCallbacksProc.run
        expect(service.callback_log).to eq([
          :around_service_before_proc,
          [:around_step_before_proc, :do_work],
          :do_work,
          [:around_step_after_proc, :do_work],
          :around_service_after_proc,
        ])
      end
    end

    context "with multiple around callbacks" do
      it "nests callbacks in order" do
        service = WithMultipleAroundCallbacks.run
        expect(service.callback_log).to eq([
          :outer_before,
          :inner_before,
          :do_work,
          :inner_after,
          :outer_after,
        ])
      end
    end
  end

  describe "step callbacks with symbols" do
    describe "before_step_run" do
      it "is called before each step" do
        service = WithCallbacks.run
        expect(service.callback_log).to include([:before_step_run, :letter_a])
        expect(service.callback_log).to include([:before_step_run, :letter_b])
      end
    end

    describe "after_step_run" do
      it "is called after each step" do
        service = WithCallbacks.run
        expect(service.callback_log).to include([:after_step_run, :letter_a])
        expect(service.callback_log).to include([:after_step_run, :letter_b])
      end
    end

    describe "on_step_success" do
      it "is called after successful step execution" do
        service = WithCallbacks.run
        expect(service.callback_log).to include([:on_step_success, :letter_a])
        expect(service.callback_log).to include([:on_step_success, :letter_b])
      end
    end

    describe "on_step_failure" do
      context "when step adds errors" do
        it "is called when step produces errors" do
          service = WithCallbacksStepError.with(use_transactions: false).run
          expect(service.callback_log).to include([:on_step_failure, :add_error])
        end

        it "still calls after_step_run" do
          service = WithCallbacksStepError.with(use_transactions: false).run
          expect(service.callback_log).to include([:after_step_run, :add_error])
        end

        it "does not call on_step_success" do
          service = WithCallbacksStepError.with(use_transactions: false).run
          expect(service.callback_log).not_to include([:on_step_success, :add_error])
        end
      end
    end

    describe "on_step_crash" do
      let(:control_flow_service_class) do
        Class.new(Operandi::Base) do
          arg :action, type: Symbol

          output :callback_log, type: Array, default: -> { [] }

          on_step_crash :log_step_crash

          step :halt

          private

          def halt
            if action == :stop
              stop_immediately!
            else
              fail_immediately!("Expected failure")
            end
          end

          def log_step_crash(_service, step_name, _error)
            callback_log << [:on_step_crash, step_name]
          end
        end
      end

      context "when step raises an exception" do
        it "is called with the exception" do
          service = WithCallbacksStepException.new
          expect { service.call }.to raise_error(StandardError, "Step exploded!")
          expect(service.callback_log).to include([:on_step_crash, :raise_error])
        end

        it "does not call after_step_run" do
          service = WithCallbacksStepException.new
          expect { service.call }.to raise_error(StandardError)
          expect(service.callback_log).not_to include([:after_step_run, :raise_error])
        end

        it "does not call on_step_success" do
          service = WithCallbacksStepException.new
          expect { service.call }.to raise_error(StandardError)
          expect(service.callback_log).not_to include([:on_step_success, :raise_error])
        end
      end

      context "when step stops execution intentionally" do
        it "is not called for stop_immediately!" do
          service = control_flow_service_class.run(action: :stop)

          expect(service.callback_log).to be_empty
          expect(service.stopped?).to be(true)
        end

        it "is not called for fail_immediately!" do
          service = control_flow_service_class.with(use_transactions: false).run(action: :fail)

          expect(service.callback_log).to be_empty
          expect(service.failed?).to be(true)
        end
      end
    end
  end

  describe "step callbacks with procs" do
    it "executes proc callbacks with step name" do
      service = WithCallbacksProc.run
      expect(service.callback_log).to include([:before_step_run_proc, :do_work])
      expect(service.callback_log).to include([:after_step_run_proc, :do_work])
    end
  end

  describe "around_step_run" do
    context "with symbol callback" do
      it "wraps step execution" do
        service = WithAroundCallbacks.run
        expect(service.callback_log).to include([:around_step_before, :do_work])
        expect(service.callback_log).to include([:around_step_after, :do_work])
      end
    end

    context "with proc callback" do
      it "wraps step execution" do
        service = WithAroundCallbacksProc.run
        expect(service.callback_log).to include([:around_step_before_proc, :do_work])
        expect(service.callback_log).to include([:around_step_after_proc, :do_work])
      end
    end
  end

  describe "callback inheritance" do
    it "inherits callbacks from parent class" do
      service = WithCallbacksChild.run
      # Parent's before_service_run should be called
      expect(service.callback_log).to include(:before_service_run)
    end

    it "child callbacks are added to parent callbacks" do
      service = WithCallbacksChild.run
      # Both parent's and child's before_service_run should be called
      expect(service.callback_log).to include(:before_service_run)
      expect(service.callback_log).to include(:child_before_service_run)
    end

    it "executes parent callbacks before child callbacks" do
      service = WithCallbacksChild.run
      parent_index = service.callback_log.index(:before_service_run)
      child_index = service.callback_log.index(:child_before_service_run)
      expect(parent_index).to be < child_index
    end

    context "with deep inheritance (grandchild)" do
      it "inherits callbacks from all ancestors" do
        service = WithCallbacksGrandchild.run
        # Should have callbacks from parent (WithCallbacks), child, and grandchild
        expect(service.callback_log).to include(:before_service_run)
        expect(service.callback_log).to include(:child_before_service_run)
        expect(service.callback_log).to include(:grandchild_before_service_run)
      end

      it "executes callbacks in correct inheritance order" do
        service = WithCallbacksGrandchild.run
        parent_index = service.callback_log.index(:before_service_run)
        child_index = service.callback_log.index(:child_before_service_run)
        grandchild_index = service.callback_log.index(:grandchild_before_service_run)

        expect(parent_index).to be < child_index
        expect(child_index).to be < grandchild_index
      end

      it "runs step callbacks from all ancestors" do
        service = WithCallbacksGrandchild.run
        # Check that grandchild's step callback runs for all steps
        expect(service.callback_log).to include([:grandchild_after_step_run, :letter_a])
        expect(service.callback_log).to include([:grandchild_after_step_run, :letter_b])
        expect(service.callback_log).to include([:grandchild_after_step_run, :letter_c])
        expect(service.callback_log).to include([:grandchild_after_step_run, :letter_d])
      end
    end

    context "with all callback types inherited" do
      it "inherits before_service_run callbacks" do
        service = WithCallbacksChildComplete.run
        expect(service.callback_log).to include(:parent_before_service)
        expect(service.callback_log).to include(:child_before_service)
      end

      it "inherits after_service_run callbacks" do
        service = WithCallbacksChildComplete.run
        expect(service.callback_log).to include(:parent_after_service)
        expect(service.callback_log).to include(:child_after_service)
      end

      it "inherits on_service_success callbacks" do
        service = WithCallbacksChildComplete.run
        expect(service.callback_log).to include(:parent_on_success)
        expect(service.callback_log).to include(:child_on_success)
      end

      it "inherits around_service_run callbacks and nests them correctly" do
        service = WithCallbacksChildComplete.run
        # Parent's around should wrap child's around
        parent_before_idx = service.callback_log.index(:parent_around_service_before)
        child_before_idx = service.callback_log.index(:child_around_service_before)
        child_after_idx = service.callback_log.index(:child_around_service_after)
        parent_after_idx = service.callback_log.index(:parent_around_service_after)

        expect(parent_before_idx).to be < child_before_idx
        expect(child_before_idx).to be < child_after_idx
        expect(child_after_idx).to be < parent_after_idx
      end

      it "inherits before_step_run callbacks" do
        service = WithCallbacksChildComplete.run
        expect(service.callback_log).to include([:parent_before_step, :parent_work])
        expect(service.callback_log).to include([:child_before_step, :parent_work])
      end

      it "inherits after_step_run callbacks" do
        service = WithCallbacksChildComplete.run
        expect(service.callback_log).to include([:parent_after_step, :parent_work])
        expect(service.callback_log).to include([:child_after_step, :parent_work])
      end

      it "inherits on_step_success callbacks" do
        service = WithCallbacksChildComplete.run
        expect(service.callback_log).to include([:parent_step_success, :child_work])
        expect(service.callback_log).to include([:child_step_success, :child_work])
      end

      it "inherits around_step_run callbacks and nests them correctly" do
        service = WithCallbacksChildComplete.run
        # Find indices for parent_work step
        parent_around_before = service.callback_log.index([:parent_around_step_before, :parent_work])
        child_around_before = service.callback_log.index([:child_around_step_before, :parent_work])
        child_around_after = service.callback_log.index([:child_around_step_after, :parent_work])
        parent_around_after = service.callback_log.index([:parent_around_step_after, :parent_work])

        expect(parent_around_before).to be < child_around_before
        expect(child_around_before).to be < child_around_after
        expect(child_around_after).to be < parent_around_after
      end
    end
  end

  describe "service instance verification" do
    it "passes the correct service instance to before_service_run callback" do
      service = WithCallbacksInstanceVerification.run

      before_entry = service.captured_instances.find { |e| e[0] == :before_service_run }
      expect(before_entry[1]).to eq(service.object_id)
      expect(before_entry[2]).to eq("WithCallbacksInstanceVerification")
    end

    it "passes the correct service instance to after_service_run callback" do
      service = WithCallbacksInstanceVerification.run

      after_entry = service.captured_instances.find { |e| e[0] == :after_service_run }
      expect(after_entry[1]).to eq(service.object_id)
      expect(after_entry[2]).to eq("WithCallbacksInstanceVerification")
    end

    it "passes the correct service instance to on_service_success callback" do
      service = WithCallbacksInstanceVerification.run

      success_entry = service.captured_instances.find { |e| e[0] == :on_service_success }
      expect(success_entry[1]).to eq(service.object_id)
      expect(success_entry[2]).to eq("WithCallbacksInstanceVerification")
    end

    it "passes the correct service instance to around_service_run callback" do
      service = WithCallbacksInstanceVerification.run

      around_before = service.captured_instances.find { |e| e[0] == :around_service_before }
      around_after = service.captured_instances.find { |e| e[0] == :around_service_after }

      expect(around_before[1]).to eq(service.object_id)
      expect(around_after[1]).to eq(service.object_id)
    end

    it "passes the same service instance to all service callbacks" do
      service = WithCallbacksInstanceVerification.run

      object_ids = service.captured_instances.map { |e| e[1] }.uniq
      expect(object_ids.size).to eq(1)
      expect(object_ids.first).to eq(service.object_id)
    end

    it "passes the correct service instance to before_step_run callback" do
      service = WithCallbacksInstanceVerification.run

      before_step = service.captured_step_instances.find { |e| e[0] == :before_step_run }
      expect(before_step[2]).to eq(service.object_id)
      expect(before_step[3]).to eq("WithCallbacksInstanceVerification")
    end

    it "passes the correct service instance to after_step_run callback" do
      service = WithCallbacksInstanceVerification.run

      after_step = service.captured_step_instances.find { |e| e[0] == :after_step_run }
      expect(after_step[2]).to eq(service.object_id)
      expect(after_step[3]).to eq("WithCallbacksInstanceVerification")
    end

    it "passes the correct service instance to on_step_success callback" do
      service = WithCallbacksInstanceVerification.run

      step_success = service.captured_step_instances.find { |e| e[0] == :on_step_success }
      expect(step_success[2]).to eq(service.object_id)
      expect(step_success[3]).to eq("WithCallbacksInstanceVerification")
    end

    it "passes the correct service instance to around_step_run callback" do
      service = WithCallbacksInstanceVerification.run

      around_before = service.captured_step_instances.find { |e| e[0] == :around_step_before }
      around_after = service.captured_step_instances.find { |e| e[0] == :around_step_after }

      expect(around_before[2]).to eq(service.object_id)
      expect(around_after[2]).to eq(service.object_id)
    end

    it "passes the same service instance to all step callbacks" do
      service = WithCallbacksInstanceVerification.run

      object_ids = service.captured_step_instances.map { |e| e[2] }.uniq
      expect(object_ids.size).to eq(1)
      expect(object_ids.first).to eq(service.object_id)
    end

    it "provides access to service state in callbacks" do
      service = WithCallbacksInstanceVerification.run

      # The service completed its work
      expect(service.result).to eq("completed")
    end
  end

  describe "callback execution order" do
    it "executes service callbacks in correct order for success" do
      service = WithCallbacks.run

      # Extract only service-level callbacks
      service_callbacks = service.callback_log.select { |c| c.is_a?(Symbol) }

      expect(service_callbacks).to eq([
        :before_service_run,
        :after_service_run,
        :on_service_success,
      ])
    end

    it "executes service callbacks in correct order for failure" do
      service = WithCallbacksFailure.with(use_transactions: false).run

      expect(service.callback_log).to eq([
        :before_service_run,
        :after_service_run,
        :on_service_failure,
      ])
    end

    it "executes step callbacks in correct order for each step" do
      service = WithCallbacks.run

      # Find callbacks for letter_a step
      letter_a_callbacks = service.callback_log.select do |c|
        c.is_a?(Array) && c[1] == :letter_a
      end

      expect(letter_a_callbacks.map(&:first)).to eq([
        :before_step_run,
        :after_step_run,
        :on_step_success,
      ])
    end
  end

  describe "DSL registration" do
    it "raises error when callback is not a symbol or proc" do
      expect do
        Class.new(Operandi::Base) do
          before_service_run "invalid"
        end
      end.to raise_error(ArgumentError, /must be a Symbol or Proc/)
    end

    it "raises error when neither symbol nor block is provided" do
      expect do
        Class.new(Operandi::Base) do
          before_service_run
        end
      end.to raise_error(ArgumentError, /requires a method name/)
    end
  end

  describe "execute_callback" do
    it "raises error when callback is not a Symbol or Proc at runtime" do
      test_class = Class.new(Operandi::Base) do
        step :do_work

        private

        def do_work
          execute_callback("invalid_callback", [])
        end
      end

      expect { test_class.run }.to raise_error(ArgumentError, /Callback must be a Symbol or Proc/)
    end
  end
end
