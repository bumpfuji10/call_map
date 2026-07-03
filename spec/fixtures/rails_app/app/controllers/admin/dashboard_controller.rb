# frozen_string_literal: true

module Admin
  # Compact-style class definition that already includes the namespace.
  class Admin::DashboardController
    before_action :require_admin, only: :show

    def show
      # Resolves via the OUTER module scope (Admin::DashboardHelper) even
      # though the class itself is written compact-style.
      DashboardHelper.render
    end

    private

    def require_admin
      true
    end
  end

  class DashboardHelper
    def self.render
      :rendered
    end
  end
end
