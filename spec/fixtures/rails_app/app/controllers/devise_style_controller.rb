# frozen_string_literal: true

# No superclass in the fixture app — authenticate_user! stays unresolved,
# mimicking a Devise-provided callback.
class DeviseStyleController
  before_action :authenticate_user!

  def show
    :ok
  end
end
