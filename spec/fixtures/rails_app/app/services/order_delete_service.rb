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
end