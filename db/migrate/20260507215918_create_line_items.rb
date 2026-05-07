class CreateLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :line_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      # Unit price snapshot at the time the line item was added so historical
      # totals are stable even if the catalog price changes later.
      t.decimal :unit_price, precision: 12, scale: 2, null: false

      t.timestamps
    end
    add_check_constraint :line_items, "quantity > 0", name: "line_items_quantity_positive"
  end
end
