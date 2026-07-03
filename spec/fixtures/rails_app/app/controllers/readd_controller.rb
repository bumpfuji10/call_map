# frozen_string_literal: true

class ReaddController < ApplicationController
  # Skip the inherited callback, then re-add it — the re-added one runs.
  skip_before_action :authenticate_user!, only: :show
  before_action :authenticate_user!, only: :show

  def show
    :ok
  end
end
