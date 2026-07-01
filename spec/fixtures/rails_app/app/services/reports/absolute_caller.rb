# frozen_string_literal: true

module Reports
  class AbsoluteCaller
    def run
      ::TopLevelService.execute
    end
  end
end
