# frozen_string_literal: true

class OrderPolicy
  def initialize(user, order)
    @user = user
    @order = order
  end

  def show?
    owner_or_admin?
  end

  def destroy?
    admin?
  end

  private

  def owner_or_admin?
    @order.user_id == @user.id || admin?
  end

  def admin?
    @user.admin?
  end
end
