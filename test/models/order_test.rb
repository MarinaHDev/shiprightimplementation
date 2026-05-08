require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "starts in pending state" do
    order = create(:order)
    assert order.pending?
  end

  test "auto-assigns a number when missing" do
    order = build(:order, number: nil)
    order.valid?
    assert_match(/\AORD-/, order.number)
  end

  test "happy path: pending -> approved -> shipped -> delivered" do
    order = create(:order)

    assert order.approve!
    assert order.approved?
    assert order.approved_at.present?

    assert order.ship!
    assert order.shipped?
    assert order.shipped_at.present?

    assert order.deliver!
    assert order.delivered?
    assert order.delivered_at.present?
  end

  test "cannot ship from pending" do
    order = create(:order)
    refute order.may_ship?
  end

  test "cannot cancel a delivered order" do
    order = create(:order, :delivered)
    refute order.may_cancel?
  end

  test "cannot deliver an order that hasn't shipped" do
    order = create(:order, :approved)
    refute order.may_deliver?
  end

  test "ship requires a tracking number and carrier" do
    order = create(:order, :approved, tracking_number: nil)
    refute order.may_ship?, "should not be shippable without tracking number"
  end

  test "audit history records each status change" do
    order = create(:order)
    PaperTrail.request(whodunnit: "tester@example.com") do
      order.approve!
      order.ship!
    end

    history = order.audit_history
    status_changes = history.filter_map { |h| h.changes["status"] }

    assert_equal [ [ "pending", "approved" ], [ "approved", "shipped" ] ], status_changes
    assert_equal "tester@example.com", history.last.whodunnit
  end

  test "available_events reflects the current state" do
    order = create(:order)
    assert_equal [ :approve, :cancel ].sort, order.available_events.sort

    order.approve!
    assert_equal [ :ship, :cancel ].sort, order.available_events.sort
  end

  test "total sums line item subtotals" do
    order = create(:order, with_line_items: 0)
    create(:line_item, order: order, quantity: 2, unit_price: 10.00)
    create(:line_item, order: order, quantity: 3, unit_price: 5.50)
    assert_equal 36.50, order.total
  end
end
