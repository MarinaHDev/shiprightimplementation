require "test_helper"

class Orders::BulkTransitionTest < ActiveSupport::TestCase
  test "applies the event to each eligible order" do
    eligible = create_list(:order, 3)
    ineligible = create(:order, :delivered)

    summary = Orders::BulkTransition.call(eligible.map(&:id) + [ineligible.id], :approve)

    assert_equal 4, summary.total
    assert_equal 3, summary.succeeded
    assert_equal 1, summary.failed

    eligible.each { |o| assert o.reload.approved? }
    assert ineligible.reload.delivered?, "ineligible orders are unchanged"
  end

  test "summary message is human readable" do
    summary = Orders::BulkTransition::Summary.new(total: 5, succeeded: 5, failed: 0)
    assert_equal "Updated 5 of 5 orders.", summary.flash_message
  end
end
