require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as(@user)
  end

  test "index requires authentication" do
    sign_out
    get orders_path
    assert_redirected_to new_session_path
  end

  test "index lists orders" do
    create_list(:order, 3)
    get orders_path
    assert_response :success
    assert_select "tbody tr", count: 3
  end

  test "index filters by status" do
    pending = create(:order)
    create(:order, :delivered)

    get orders_path(status: "pending")
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_match pending.number, response.body
  end

  test "valid transition redirects with notice" do
    order = create(:order)
    post transition_order_path(order), params: { event: "approve" }
    assert_redirected_to order
    follow_redirect!
    assert_match(/updated to approved/, response.body)
    assert order.reload.approved?
  end

  test "invalid transition redirects with friendly alert, not 500" do
    order = create(:order, :delivered)
    post transition_order_path(order), params: { event: "cancel" }
    assert_redirected_to order
    follow_redirect!
    assert_match(/Cannot cancel an order that is delivered/, response.body)
    assert order.reload.delivered?
  end

  test "bulk_transition applies the event to selected orders" do
    orders = create_list(:order, 2)
    post bulk_transition_orders_path, params: { event: "approve", order_ids: orders.map(&:id) }
    assert_redirected_to orders_path(status: nil)
    follow_redirect!
    assert_match(/Updated 2 of 2/, response.body)
  end

  test "bulk_transition with empty selection shows alert" do
    post bulk_transition_orders_path, params: { event: "approve", order_ids: [] }
    assert_redirected_to orders_path(status: nil)
    follow_redirect!
    assert_match(/Select at least one/, response.body)
  end

  test "sync_tracking enqueues the job" do
    order = create(:order, :shipped)
    assert_enqueued_with(job: TrackingSyncJob, args: [order.id]) do
      post sync_tracking_order_path(order)
    end
    assert_redirected_to order
  end
end
