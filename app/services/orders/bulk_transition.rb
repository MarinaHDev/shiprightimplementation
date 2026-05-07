module Orders
  class BulkTransition
    Summary = Data.define(:total, :succeeded, :failed) do
      def flash_message
        if failed.zero?
          "Updated #{succeeded} of #{total} order#{'s' if total != 1}."
        else
          "Updated #{succeeded} of #{total}; #{failed} skipped (invalid for the requested action)."
        end
      end
    end

    def self.call(order_ids, event)
      orders = Order.where(id: order_ids)
      results = orders.map { |o| Transition.call(o, event) }
      Summary.new(
        total:     results.size,
        succeeded: results.count(&:success?),
        failed:    results.count(&:failure?)
      )
    end
  end
end
