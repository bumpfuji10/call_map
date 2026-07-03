# frozen_string_literal: true

class DynamicDispatchService
  def self.execute
    new.send(:perform)
  end

  def perform
    validate
  end

  private

  def validate
    true
  end
end
