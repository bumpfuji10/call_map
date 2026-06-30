# frozen_string_literal: true

class OrderDeletionPolicy
  def initialize(user, order)
    @user = user
    @order = order
  end

  def validate!
    raise "not deletable" unless @order.deletable?
  end
end
