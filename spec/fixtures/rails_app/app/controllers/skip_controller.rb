# frozen_string_literal: true

class SkipController < ApplicationController
  skip_before_action :authenticate_user!, only: :show
  before_action :lightweight_check, only: :show

  def show
    :ok
  end

  def edit
    :ok
  end

  private

  def lightweight_check
    true
  end
end
