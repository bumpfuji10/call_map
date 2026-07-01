# frozen_string_literal: true

module SomeNamespace
  # Absolute class definition — should NOT be nested under SomeNamespace.
  class ::TopLevelService
    def run
      :running
    end
  end
end
