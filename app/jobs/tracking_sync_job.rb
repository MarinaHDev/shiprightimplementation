class TrackingSyncJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError
  discard_on ActiveRecord::RecordNotFound

  def perform(order_id)
    order = Order.find(order_id)

    if order.tracking_number.blank?
      Rails.logger.info("[TrackingSyncJob] skipped order=#{order.id} reason=no_tracking_number")
      return
    end

    result = Carrier.gateway.fetch_events(tracking_number: order.tracking_number)

    if result.failure?
      Rails.logger.warn("[TrackingSyncJob] failed order=#{order.id} error=#{result.error}")
      return
    end

    persist_events(order, result.events)
    order.update_column(:last_tracking_synced_at, Time.current)

    broadcast_refresh(order)
    Rails.logger.info("[TrackingSyncJob] synced order=#{order.id} events=#{result.events.size}")
  end

  private

  def persist_events(order, events)
    events.each do |event|
      record = order.tracking_events.find_or_initialize_by(carrier_event_id: event.carrier_event_id)
      record.assign_attributes(event.to_attributes)
      record.save! if record.changed?
    end
  end

  def broadcast_refresh(order)
    Turbo::StreamsChannel.broadcast_replace_to(
      order,
      target: helpers.dom_id(order, :tracking),
      partial: "orders/tracking_timeline",
      locals: { order: order }
    )
  end

  def helpers
    @helpers ||= ApplicationController.helpers
  end
end
