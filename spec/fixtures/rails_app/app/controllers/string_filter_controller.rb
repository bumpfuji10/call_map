# frozen_string_literal: true

class StringFilterController
  before_action :audit, only: "show"
  before_action :block_destroy, except: ["show"]

  def show
    :ok
  end

  private

  def audit
    true
  end

  def block_destroy
    true
  end
end
