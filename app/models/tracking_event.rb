class TrackingEvent < ApplicationRecord
  belongs_to :order

  validates :occurred_at, presence: true
  validates :status, presence: true
  validates :carrier_event_id, presence: true,
            uniqueness: { scope: :order_id }

  scope :chronological, -> { order(occurred_at: :asc) }
end
