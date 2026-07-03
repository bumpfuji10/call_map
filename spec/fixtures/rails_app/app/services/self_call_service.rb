# frozen_string_literal: true

class SelfCallService
  def run
    self.helper
  end

  def self.helper
    :class_level
  end

  def helper
    :instance_level
  end
end
