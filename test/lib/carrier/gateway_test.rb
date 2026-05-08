require "test_helper"

class Carrier::GatewayTest < ActiveSupport::TestCase
  class FlakyClient
    def initialize(failures_before_success: 0, raise_class: Carrier::TransientError)
      @failures = failures_before_success
      @raise_class = raise_class
      @calls = 0
    end
    attr_reader :calls

    def fetch_events(tracking_number:)
      @calls += 1
      if @calls <= @failures
        raise @raise_class, "boom"
      end
      [Carrier::Event.new(carrier_event_id: "1", occurred_at: Time.current, status: "in_transit", description: "ok", location: "Hub")]
    end
  end

  class AlwaysRaisesClient
    def initialize(raise_class)
      @raise_class = raise_class
    end

    def fetch_events(tracking_number:)
      raise @raise_class, "boom"
    end
  end

  test "returns a successful result for normal responses" do
    gateway = Carrier::Gateway.new(client: FlakyClient.new(failures_before_success: 0), backoff: 0)
    result = gateway.fetch_events(tracking_number: "T1")
    assert result.success?
    assert_equal 1, result.events.size
  end

  test "retries transient errors up to the configured limit" do
    client = FlakyClient.new(failures_before_success: 2)
    gateway = Carrier::Gateway.new(client: client, retries: 2, backoff: 0)
    result = gateway.fetch_events(tracking_number: "T2")
    assert result.success?
    assert_equal 3, client.calls, "expected 2 failures + 1 success"
  end

  test "gives up after exhausting retries" do
    client = FlakyClient.new(failures_before_success: 99)
    gateway = Carrier::Gateway.new(client: client, retries: 2, backoff: 0)
    result = gateway.fetch_events(tracking_number: "T3")
    assert result.failure?
    assert_equal 3, client.calls
  end

  test "does not retry NotFound" do
    client = AlwaysRaisesClient.new(Carrier::NotFound)
    gateway = Carrier::Gateway.new(client: client, retries: 5, backoff: 0)
    result = gateway.fetch_events(tracking_number: "MISSING")
    assert result.failure?
  end

  test "swallows unexpected errors and returns failure" do
    client = AlwaysRaisesClient.new(StandardError)
    gateway = Carrier::Gateway.new(client: client, backoff: 0)
    result = gateway.fetch_events(tracking_number: "X")
    assert result.failure?
    assert_match(/Unexpected/, result.error)
  end

  test "rejects malformed events at the boundary" do
    bad_client = Class.new do
      define_method(:fetch_events) do |tracking_number:|
        [Carrier::Event.new(carrier_event_id: nil, occurred_at: Time.current, status: "x", description: nil, location: nil)]
      end
    end.new

    gateway = Carrier::Gateway.new(client: bad_client, backoff: 0)
    result = gateway.fetch_events(tracking_number: "T")
    assert result.failure?
    assert_match(/missing carrier_event_id/, result.error)
  end
end
