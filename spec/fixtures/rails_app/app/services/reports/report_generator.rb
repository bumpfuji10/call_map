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
end
