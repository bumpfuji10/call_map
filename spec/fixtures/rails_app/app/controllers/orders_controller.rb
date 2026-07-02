# frozen_string_literal: true

class OrdersController < ApplicationController
  before_action :authenticate, :set_order, only: %i[show destroy]

  def show
    authorize @order, policy_class: OrderPolicy
  end

  def destroy
    authorize @order, policy_class: OrderPolicy
    OrderDeleteService.execute(order: @order)
    OrderNotifier.notify_deletion(order: @order)
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end
end
