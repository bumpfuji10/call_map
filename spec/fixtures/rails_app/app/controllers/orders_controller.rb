# frozen_string_literal: true

class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [:destroy]

  def destroy
    authorize_order!
    OrderDeleteService.execute(order: @order, user: current_user)
    redirect_to orders_path
  end

  private

  def set_order
    @order = current_user.orders.find(params[:id])
  end

  def authorize_order!
    OrderPolicy.new(current_user, @order).destroy?
  end
end
