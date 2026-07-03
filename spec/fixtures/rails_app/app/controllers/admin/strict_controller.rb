# frozen_string_literal: true

module Admin
  # Absolute superclass — inherits from the top-level ApplicationController,
  # NOT Admin::ApplicationController.
  class StrictController < ::ApplicationController
    def show
      :ok
    end
  end
end
