module Carrier
  class FakeClient
    DEFAULT_PROGRESSION = [
      { status: "label_created",      description: "Shipping label created",          location: "Origin Facility" },
      { status: "picked_up",          description: "Picked up by carrier",             location: "Origin Facility" },
      { status: "in_transit",         description: "Departed origin facility",         location: "Origin Hub" },
      { status: "in_transit",         description: "Arrived at regional sort center",  location: "Regional Hub" },
      { status: "out_for_delivery",   description: "Out for delivery",                 location: "Local Depot" },
      { status: "delivered",          description: "Delivered to recipient",           location: "Destination" }
    ].freeze

    def initialize(failure_rate: 0.0, latency: 0.0, clock: -> { Time.current }, random: Random.new)
      @failure_rate = failure_rate
      @latency = latency
      @clock = clock
      @random = random
    end

    def fetch_events(tracking_number:)
      raise ArgumentError, "tracking_number is required" if tracking_number.blank?

      sleep(@latency) if @latency.positive?

      if @random.rand < @failure_rate
        raise Carrier::TransientError, "carrier API timed out for #{tracking_number}"
      end

      raise Carrier::NotFound, "no shipment for #{tracking_number}" if tracking_number == "INVALID"

      build_events_for(tracking_number)
    end

    private

    def build_events_for(tracking_number)
      seed = Digest::SHA256.hexdigest(tracking_number).to_i(16)
      rng = Random.new(seed)
      progress = rng.rand(2..DEFAULT_PROGRESSION.length)
      base_time = @clock.call - (progress * 6).hours

      DEFAULT_PROGRESSION.first(progress).each_with_index.map do |event, idx|
        Carrier::Event.new(
          carrier_event_id: "#{tracking_number}-#{idx}",
          occurred_at:      base_time + (idx * 6).hours,
          status:           event[:status],
          description:      event[:description],
          location:         event[:location]
        )
      end
    end
  end
end
