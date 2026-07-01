# frozen_string_literal: true

class ReopenedService
  def call
    :original
  end
end

class ReopenedService
  def call
    :redefined
  end
end
