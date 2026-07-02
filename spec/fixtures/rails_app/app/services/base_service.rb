# frozen_string_literal: true

class BaseService
  def self.execute
    new.perform
  end

  def perform
    true
  end
end

class ChildService < BaseService
  def self.run
    ChildService.execute
    ChildService.new.perform
  end
end
