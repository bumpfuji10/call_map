# frozen_string_literal: true

class OrderDeletedNotifier
  def self.call(order)
    new(order).deliver
  end

  def initialize(order)
    @order = order
  end

  def deliver
    # 通知処理（fixture では中身は省略）
  end
end
