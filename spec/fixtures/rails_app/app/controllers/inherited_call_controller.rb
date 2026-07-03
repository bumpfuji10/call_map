# frozen_string_literal: true

class InheritedCallController < ApplicationController
  def show
    authenticate_user!
  end
end
