require "faker"

Rails.logger.info("[seed] starting")

# Default staff user. Credentials are documented in the README.
default_email = ENV.fetch("SEED_USER_EMAIL", "ops@shipright.test")
default_password = ENV.fetch("SEED_USER_PASSWORD", "password123")

staff = User.find_or_initialize_by(email_address: default_email)
staff.assign_attributes(name: "Operations Lead", password: default_password, password_confirmation: default_password)
staff.save!
Rails.logger.info("[seed] staff user ready: #{staff.email_address}")

# Catalog
products = [
  { name: "Tactical Backpack 30L", sku: "BAG-30L",  price: 89.99 },
  { name: "Insulated Water Bottle", sku: "BTL-INS",  price: 24.50 },
  { name: "Trail Running Shoes",    sku: "SHO-TRL",  price: 129.00 },
  { name: "Wool Hiking Socks",      sku: "SCK-WOOL", price: 14.95 },
  { name: "Headlamp 500lm",         sku: "LMP-500",  price: 39.99 },
  { name: "Carbon Trekking Poles",  sku: "POL-CRBN", price: 145.00 },
  { name: "Down Sleeping Bag",      sku: "SLP-DOWN", price: 219.00 }
].map do |attrs|
  Product.find_or_create_by!(sku: attrs[:sku]) { |p| p.assign_attributes(attrs) }
end
Rails.logger.info("[seed] products: #{Product.count}")

def make_order(products, status:)
  order = Order.create!(
    customer_name: Faker::Name.name,
    customer_email: Faker::Internet.email,
    shipping_address: Faker::Address.full_address,
    carrier: %w[UPS FedEx USPS DHL].sample,
    tracking_number: "TRK#{SecureRandom.alphanumeric(10).upcase}"
  )
  rand(1..3).times do
    product = products.sample
    LineItem.create!(order: order, product: product, quantity: rand(1..4), unit_price: product.price)
  end
  drive_to_status(order, status)
  order
end

def drive_to_status(order, target)
  case target
  when "pending"
    # already pending after create
  when "approved"
    order.approve!
  when "shipped"
    order.approve!
    order.ship!
  when "delivered"
    order.approve!
    order.ship!
    order.deliver!
  when "cancelled"
    order.cancel!
  end
end

if Order.count.zero?
  PaperTrail.request(whodunnit: "seed") do
    distribution = {
      "pending"   => 6,
      "approved"  => 4,
      "shipped"   => 5,
      "delivered" => 3,
      "cancelled" => 2
    }
    distribution.each do |status, count|
      count.times { make_order(products, status: status) }
    end
  end
  Rails.logger.info("[seed] orders created: #{Order.count}")
else
  Rails.logger.info("[seed] orders already present (#{Order.count}) — skipping")
end

Order.where(status: %w[shipped delivered]).find_each do |order|
  next if order.tracking_events.exists?
  result = Carrier.gateway.fetch_events(tracking_number: order.tracking_number)
  next unless result.success?
  result.events.each do |event|
    record = order.tracking_events.find_or_initialize_by(carrier_event_id: event.carrier_event_id)
    record.assign_attributes(event.to_attributes)
    record.save!
  end
  order.update_column(:last_tracking_synced_at, Time.current)
end

Rails.logger.info("[seed] done")
