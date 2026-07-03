# frozen_string_literal: true

class BaseJob
  # Constant nested in the parent class — visible from subclasses.
  class Worker
    def self.call
      true
    end
  end
end

class ChildJob < BaseJob
  def run
    Worker.call
  end
end
