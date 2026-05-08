FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "staff#{n}@shipright.test" }
    name     { "Staff User" }
    password { "password123" }
    password_confirmation { "password123" }
  end

  factory :product do
    sequence(:sku)  { |n| "SKU-#{n.to_s.rjust(4, "0")}" }
    sequence(:name) { |n| "Product #{n}" }
    price  { 19.99 }
    active { true }
  end

  factory :order do
    sequence(:number) { |n| "ORD-#{n.to_s.rjust(6, "0")}" }
    customer_name     { "Jane Customer" }
    customer_email    { "jane@example.com" }
    shipping_address  { "123 Main St\nSpringfield" }
    carrier           { "UPS" }
    sequence(:tracking_number) { |n| "TRK#{n.to_s.rjust(8, "0")}" }
    status { "pending" }

    transient do
      with_line_items { 1 }
    end

    after(:create) do |order, evaluator|
      evaluator.with_line_items.times { create(:line_item, order: order) }
    end

    trait :approved   do; status { "approved" };  approved_at { Time.current }; end
    trait :shipped    do; status { "shipped" };   approved_at { 2.hours.ago }; shipped_at { Time.current }; end
    trait :delivered  do; status { "delivered" }; approved_at { 1.day.ago }; shipped_at { 12.hours.ago }; delivered_at { Time.current }; end
    trait :cancelled  do; status { "cancelled" }; cancelled_at { Time.current }; end
  end

  factory :line_item do
    order
    product
    quantity { 2 }
    unit_price { 19.99 }
  end

  factory :tracking_event do
    order
    sequence(:carrier_event_id) { |n| "EVT-#{n}" }
    occurred_at { Time.current }
    status      { "in_transit" }
    description { "Departed origin facility" }
    location    { "Origin Hub" }
  end
end
