module Carrier
  Event = Data.define(:carrier_event_id, :occurred_at, :status, :description, :location) do
    def to_attributes
      {
        carrier_event_id: carrier_event_id,
        occurred_at:      occurred_at,
        status:           status,
        description:      description,
        location:         location
      }
    end
  end
end
