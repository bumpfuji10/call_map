# frozen_string_literal: true

module Admin
  class ReportsController
    def index
      Report.recent
    end
  end
end