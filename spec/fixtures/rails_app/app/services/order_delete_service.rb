# frozen_string_literal: true

class OrderDeleteService
  def self.execute(order:)
    new(order).execute
  end

  def initialize(order:)
    @order = order
  end

  def execute
    @order.destroy!
  end

  # Same-name constant receiver — should resolve to OrderDeleteService.cleanup,
  # not OrderDeleteService::OrderDeleteService.cleanup.
  def OrderDeleteService.cleanup
    :cleanup
  end
end