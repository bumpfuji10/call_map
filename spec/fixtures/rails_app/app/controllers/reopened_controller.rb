# frozen_string_literal: true

class ReopenedController
  before_action :auth, only: :show
end

# Reopened — callbacks declared here also run for the action.
class ReopenedController
  before_action :audit, only: :show

  def show
    :ok
  end

  private

  def auth
    true
  end

  def audit
    true
  end
end
