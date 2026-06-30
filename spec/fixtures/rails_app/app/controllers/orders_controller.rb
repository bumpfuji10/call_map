# frozen_string_literal: true

class OrdersController < ApplicationController
  def destroy
    set_order
    OrderDeleteService.execute(order: @order)
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end
end