# frozen_string_literal: true

class OrderNotifier
  def self.notify_deletion(order:)
    new(order).send_notification
  end

  def initialize(order)
    @order = order
  end

  def send_notification
    deliver(@order.user)
  end

  private

  def deliver(recipient)
    recipient.notify("Order #{@order.id} deleted")
  end
end
