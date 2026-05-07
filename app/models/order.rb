class Order < ApplicationRecord
  include AASM
  include Auditable

  has_many :line_items, dependent: :destroy, inverse_of: :order
  has_many :products, through: :line_items
  has_many :tracking_events, dependent: :destroy

  accepts_nested_attributes_for :line_items, allow_destroy: true,
                                reject_if: ->(attrs) { attrs[:product_id].blank? }

  before_validation :assign_number, on: :create

  validates :number, presence: true, uniqueness: true
  validates :customer_name, presence: true
  validates :customer_email, presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :shipping_address, presence: true
  validates :status, presence: true

  audited only: [:status]

  STATUSES = %w[pending approved shipped delivered cancelled].freeze

  aasm column: :status, whiny_persistence: true do
    state :pending, initial: true
    state :approved
    state :shipped
    state :delivered
    state :cancelled

    event :approve do
      transitions from: :pending, to: :approved, after: :record_approval
    end

    event :ship do
      transitions from: :approved, to: :shipped,
                  guard: :shippable?,
                  after: :record_shipment
    end

    event :deliver do
      transitions from: :shipped, to: :delivered, after: :record_delivery
    end

    event :cancel do
      transitions from: [:pending, :approved, :shipped], to: :cancelled,
                  after: :record_cancellation
    end
  end

  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :awaiting_action, -> { where(status: %w[pending approved shipped]) }

  def total
    line_items.sum { |li| li.subtotal }
  end

  def shippable?
    line_items.any? && carrier.present? && tracking_number.present?
  end

  def available_events
    aasm.events(permitted: true).map(&:name)
  end

  private

  def assign_number
    return if number.present?
    self.number = "ORD-#{SecureRandom.hex(4).upcase}"
  end

  def record_approval
    update_columns(approved_at: Time.current)
  end

  def record_shipment
    update_columns(shipped_at: Time.current)
  end

  def record_delivery
    update_columns(delivered_at: Time.current)
  end

  def record_cancellation
    update_columns(cancelled_at: Time.current)
  end
end
