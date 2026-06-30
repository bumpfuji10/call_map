# frozen_string_literal: true

class OrderDeleteService
  def self.execute(order:, user:)
    new(order:, user:).execute
  end

  def initialize(order:, user:)
    @order = order
    @user = user
  end

  def execute
    validate_deletable!
    destroy_order!
    notify_deleted
  end

  private

  def validate_deletable!
    OrderDeletionPolicy.new(@user, @order).validate!
  end

  def destroy_order!
    @order.destroy!
  end

  def notify_deleted
    OrderDeletedNotifier.call(@order)
  end
end
