# frozen_string_literal: true

module Reports
  class Generator
  end

  # Class method on a namespaced constant via a constant receiver.
  def Generator.reset
    :reset
  end

  # Class method on a namespaced constant via `class << Constant`.
  class << Generator
    def build
      new
    end
  end

  # Absolute constant path — should NOT be double-prefixed.
  class << ::Reports::Generator
    def export
      :export
    end
  end
end
