module Carrier
  class Gateway
    Result = Data.define(:success?, :events, :error) do
      def failure? = !success?
    end

    DEFAULT_RETRIES = 2
    DEFAULT_BACKOFF = 0.25

    def initialize(client: nil, retries: DEFAULT_RETRIES, backoff: DEFAULT_BACKOFF, logger: Rails.logger)
      @client = client || self.class.default_client
      @retries = retries
      @backoff = backoff
      @logger = logger
    end

    def fetch_events(tracking_number:)
      attempts = 0
      begin
        attempts += 1
        events = @client.fetch_events(tracking_number: tracking_number)
        validate!(events)
        Result.new(success?: true, events: events, error: nil)
      rescue Carrier::TransientError => e
        if attempts <= @retries
          @logger.warn("[Carrier] transient error attempt=#{attempts} tracking=#{tracking_number} err=#{e.message}")
          sleep(@backoff * attempts) if @backoff.positive?
          retry
        end
        @logger.error("[Carrier] giving up after #{attempts} attempts tracking=#{tracking_number} err=#{e.message}")
        Result.new(success?: false, events: [], error: e.message)
      rescue Carrier::NotFound => e
        @logger.warn("[Carrier] not found tracking=#{tracking_number}")
        Result.new(success?: false, events: [], error: e.message)
      rescue Carrier::MalformedResponse, ArgumentError => e
        @logger.error("[Carrier] malformed response tracking=#{tracking_number} err=#{e.message}")
        Result.new(success?: false, events: [], error: e.message)
      rescue StandardError => e
        @logger.error("[Carrier] unexpected error tracking=#{tracking_number} err=#{e.class}: #{e.message}")
        Result.new(success?: false, events: [], error: "Unexpected carrier error")
      end
    end

    def self.default_client
      Carrier::FakeClient.new(failure_rate: ENV.fetch("CARRIER_FAILURE_RATE", "0.1").to_f,
                              latency: ENV.fetch("CARRIER_LATENCY_SECONDS", "0.2").to_f)
    end

    private

    def validate!(events)
      raise Carrier::MalformedResponse, "expected Array, got #{events.class}" unless events.is_a?(Array)
      events.each do |e|
        raise Carrier::MalformedResponse, "event missing carrier_event_id" if e.carrier_event_id.blank?
        raise Carrier::MalformedResponse, "event missing occurred_at" if e.occurred_at.blank?
      end
    end
  end
end
