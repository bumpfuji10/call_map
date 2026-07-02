# frozen_string_literal: true

class SelfNewService
  def self.execute
    self.new.perform
  end

  def perform
    validate
  end

  def validate
    true
  end
end
