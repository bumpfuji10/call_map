# frozen_string_literal: true

module Reports
  class Publisher
    # Shadowing constant under the owner — must NOT be picked up from an
    # explicit-receiver definition below.
    class Notifier
      def self.deliver
        :wrong
      end
    end
  end

  # Explicit-receiver class method: constants inside resolve against the
  # lexical scope (Reports), not against Publisher's namespace.
  def Publisher.announce
    Notifier.deliver
  end

  class Notifier
    def self.deliver
      :right
    end
  end
end
