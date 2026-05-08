require "test_helper"

class TrackingSyncJobTest < ActiveJob::TestCase
  class StubGateway
    Result = Struct.new(:success?, :events, :error, keyword_init: true) do
      def failure? = !success?
    end

    def initialize(events: [], error: nil)
      @events = events
      @error = error
    end

    def fetch_events(tracking_number:)
      if @error
        Result.new(success?: false, events: [], error: @error)
      else
        Result.new(success?: true, events: @events, error: nil)
      end
    end
  end

  setup do
    @order = create(:order, :shipped, tracking_number: "TRK-JOB-1")
  end

  teardown { Carrier.reset_gateway! }

  test "persists events from the carrier and stamps last_tracking_synced_at" do
    Carrier.gateway = StubGateway.new(events: [
      Carrier::Event.new(carrier_event_id: "e1", occurred_at: 1.hour.ago, status: "in_transit", description: "On its way", location: "Hub"),
      Carrier::Event.new(carrier_event_id: "e2", occurred_at: 30.minutes.ago, status: "out_for_delivery", description: "Out for delivery", location: "Local"),
    ])

    assert_difference -> { @order.tracking_events.count }, 2 do
      TrackingSyncJob.perform_now(@order.id)
    end
    assert @order.reload.last_tracking_synced_at.present?
  end

  test "is idempotent — repeat syncs do not duplicate events" do
    events = [
      Carrier::Event.new(carrier_event_id: "e1", occurred_at: 1.hour.ago, status: "in_transit", description: "x", location: "y")
    ]
    Carrier.gateway = StubGateway.new(events: events)

    TrackingSyncJob.perform_now(@order.id)
    assert_no_difference -> { TrackingEvent.count } do
      TrackingSyncJob.perform_now(@order.id)
    end
  end

  test "is a no-op when the carrier returns an error" do
    Carrier.gateway = StubGateway.new(error: "carrier down")

    assert_no_difference -> { TrackingEvent.count } do
      TrackingSyncJob.perform_now(@order.id)
    end
    assert_nil @order.reload.last_tracking_synced_at
  end

  test "is a no-op when the order has no tracking number" do
    Carrier.gateway = StubGateway.new(events: [])
    @order.update_column(:tracking_number, nil)

    assert_nothing_raised { TrackingSyncJob.perform_now(@order.id) }
  end

  test "discards if the order has been deleted" do
    Carrier.gateway = StubGateway.new(events: [])
    id = @order.id
    @order.destroy

    assert_nothing_raised { TrackingSyncJob.perform_now(id) }
  end
end
