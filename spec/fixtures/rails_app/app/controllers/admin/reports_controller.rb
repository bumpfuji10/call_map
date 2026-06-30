# frozen_string_literal: true

module Admin
  class ReportsController < ApplicationController
    def index
      ReportQuery.new.recent
    end
  end
end
