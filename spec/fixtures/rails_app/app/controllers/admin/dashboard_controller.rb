# frozen_string_literal: true

module Admin
  # Compact-style class definition that already includes the namespace.
  class Admin::DashboardController
    before_action :require_admin, only: :show

    def show
      :dashboard
    end

    private

    def require_admin
      true
    end
  end
end
