# frozen_string_literal: true

class CircularService
  def ping
    pong
  end

  def pong
    ping
  end
end
