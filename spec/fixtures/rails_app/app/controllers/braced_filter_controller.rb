# frozen_string_literal: true

class BracedFilterController
  before_action :audit, { only: :show }

  def show
    :ok
  end

  def edit
    :ok
  end

  private

  def audit
    true
  end
end
