class CreateTrackingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :tracking_events do |t|
      t.references :order, null: false, foreign_key: true
      t.datetime :occurred_at, null: false
      t.string :status, null: false
      t.string :description
      t.string :location

      t.string :carrier_event_id, null: false

      t.timestamps
    end
    add_index :tracking_events, [:order_id, :carrier_event_id], unique: true
    add_index :tracking_events, :occurred_at
  end
end
