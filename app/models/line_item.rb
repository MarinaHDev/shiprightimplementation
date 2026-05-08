class LineItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :snapshot_unit_price, on: :create

  def subtotal
    return 0 if quantity.nil? || unit_price.nil?
    quantity * unit_price
  end

  private

  def snapshot_unit_price
    self.unit_price ||= product&.price
  end
end
