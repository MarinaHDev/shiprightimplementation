require "test_helper"

class Orders::TransitionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  test "succeeds for a valid transition" do
    order = create(:order)

    result = Orders::Transition.call(order, :approve)

    assert result.success?
    assert order.reload.approved?
  end

  test "returns a friendly error for an invalid transition" do
    order = create(:order, :delivered)

    result = Orders::Transition.call(order, :cancel)

    assert result.failure?
    assert_equal "Cannot cancel an order that is delivered.", result.error_message
    assert order.reload.delivered?, "state must not change on a failed transition"
  end

  test "returns a friendly error for an unknown event" do
    order = create(:order)
    result = Orders::Transition.call(order, :teleport)
    assert result.failure?
    assert_match(/Unknown action/, result.error_message)
  end

  test "enqueues a tracking sync after a successful ship" do
    order = create(:order, :approved)

    assert_enqueued_with(job: TrackingSyncJob, args: [ order.id ]) do
      Orders::Transition.call(order, :ship)
    end
  end

  test "does not enqueue tracking sync on non-ship events" do
    order = create(:order)
    assert_no_enqueued_jobs(only: TrackingSyncJob) do
      Orders::Transition.call(order, :approve)
    end
  end
end
