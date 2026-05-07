module Orders
  class Transition
    Result = Data.define(:success?, :order, :error_message) do
      def failure? = !success?
    end

    EVENT_LABELS = {
      approve: "approve",
      ship:    "mark as shipped",
      deliver: "mark as delivered",
      cancel:  "cancel"
    }.freeze

    def self.call(...)
      new(...).call
    end

    def initialize(order, event)
      @order = order
      @event = event.to_sym
    end

    def call
      unless valid_event?
        return Result.new(success?: false, order: @order,
                          error_message: "Unknown action: #{@event}.")
      end

      unless @order.aasm.may_fire_event?(@event)
        return Result.new(success?: false, order: @order,
                          error_message: invalid_transition_message)
      end

      @order.public_send("#{@event}!")
      after_transition
      Result.new(success?: true, order: @order, error_message: nil)
    rescue AASM::InvalidTransition
      Result.new(success?: false, order: @order,
                 error_message: invalid_transition_message)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, order: @order,
                 error_message: e.record.errors.full_messages.to_sentence)
    end

    private

    def valid_event?
      Order.aasm.events.map(&:name).include?(@event)
    end

    def invalid_transition_message
      label = EVENT_LABELS[@event] || @event.to_s
      "Cannot #{label} an order that is #{@order.status}."
    end

    def after_transition
      if @event == :ship
        TrackingSyncJob.perform_later(@order.id)
      end
    end
  end
end
