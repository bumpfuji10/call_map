# frozen_string_literal: true

module Reports
  class ShadowRunner
    # Same-named constant exists both here and at Reports level —
    # Ruby resolves Formatter to the innermost Reports::ShadowRunner::Formatter.
    class Formatter
      def self.call
        :inner
      end
    end

    def run
      Formatter.call
    end
  end

  class Formatter
    def self.call
      :outer
    end
  end
end
