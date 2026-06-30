# frozen_string_literal: true

class OrderPolicy
  def initialize(user, order)
    @user = user
    @order = order
  end

  def destroy?
    @user.admin? || @order.user == @user
  end
end
