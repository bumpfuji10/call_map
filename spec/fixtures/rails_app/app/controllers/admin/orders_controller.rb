# frozen_string_literal: true

module Admin
  # Module-style: `ApplicationController` here must resolve to
  # Admin::ApplicationController, not the top-level one.
  class OrdersController < ApplicationController
    # Callback declared here, method inherited from the parent.
    before_action :audit_access, only: :show

    def show
      :ok
    end

    private

    # Overrides the parent's admin_guard — the callback declared by the
    # parent must resolve to this override.
    def admin_guard
      :stricter
    end
  end
end
