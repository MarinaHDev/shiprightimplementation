class Product < ApplicationRecord
  has_many :line_items, dependent: :restrict_with_error

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: { case_sensitive: false }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
end
