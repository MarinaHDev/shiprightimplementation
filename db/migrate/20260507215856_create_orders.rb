class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :number, null: false
      t.string :customer_name, null: false
      t.string :customer_email, null: false
      t.string :status, null: false, default: "pending"
      t.text :shipping_address, null: false
      t.string :carrier
      t.string :tracking_number
      t.datetime :approved_at
      t.datetime :shipped_at
      t.datetime :delivered_at
      t.datetime :cancelled_at
      t.datetime :last_tracking_synced_at

      t.timestamps
    end
    add_index :orders, :number, unique: true
    add_index :orders, :status
    add_index :orders, :tracking_number
  end
end
