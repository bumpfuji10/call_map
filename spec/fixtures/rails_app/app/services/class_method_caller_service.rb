# frozen_string_literal: true

class ClassMethodCallerService
  def self.execute
    validate
    perform
  end

  def self.validate
    true
  end

  def self.perform
    true
  end

  def validate
    false
  end
end
