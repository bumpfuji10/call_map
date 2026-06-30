# frozen_string_literal: true

class LegacyReportService
end

# Class method defined with an explicit constant receiver (not `self`).
def LegacyReportService.generate
  new.run
end
