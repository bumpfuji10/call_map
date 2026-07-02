# frozen_string_literal: true

module Admin
  class ApplicationController
    before_action :admin_guard

    private

    def admin_guard
      true
    end

    def audit_access
      true
    end
  end
end
