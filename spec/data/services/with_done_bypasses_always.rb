# frozen_string_literal: true

class WithDoneBypassesAlways < ApplicationService
  output :trace, default: []

  step :work
  step :cleanup, always: true

  private

  def work
    trace << :work

    stop!

    # Code after stop! still runs within the same step.
    trace << :after_done
  end

  def cleanup
    trace << :cleanup
  end
end
