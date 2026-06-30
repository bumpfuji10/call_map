# frozen_string_literal: true

class OrderArchiveService
  class << self
    def execute(order)
      new(order).archive
    end
  end

  def initialize(order)
    @order = order
  end

  def archive
    @order.touch(:archived_at)
  end
end
