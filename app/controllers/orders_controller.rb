class OrdersController < ApplicationController
  before_action :set_order, only: [:show, :transition, :sync_tracking]

  def index
    @status = params[:status].presence
    @counts = Order.group(:status).count
    @orders = Order.includes(:line_items).by_status(@status).recent_first
  end

  def show
    @line_items = @order.line_items.includes(:product)
    @tracking_events = @order.tracking_events.chronological
    @audit_history = @order.audit_history
  end

  def transition
    result = Orders::Transition.call(@order, params.require(:event))

    respond_to do |format|
      if result.success?
        format.html { redirect_to @order, notice: "Order #{@order.number} updated to #{@order.status}." }
      else
        format.html { redirect_to @order, alert: result.error_message }
      end
    end
  end

  def sync_tracking
    TrackingSyncJob.perform_later(@order.id)
    redirect_to @order, notice: "Tracking sync queued — the timeline will update when it's ready."
  end

  def bulk_transition
    event = params.require(:event)
    ids = Array(params[:order_ids]).reject(&:blank?)

    if ids.empty?
      redirect_to orders_path(status: params[:status]),
                  alert: "Select at least one order before applying a bulk action."
      return
    end

    summary = Orders::BulkTransition.call(ids, event)
    redirect_to orders_path(status: params[:status]), notice: summary.flash_message
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end
end
