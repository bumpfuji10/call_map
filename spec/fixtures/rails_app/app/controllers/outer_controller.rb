# frozen_string_literal: true

class OuterController
  before_action :outer_auth, only: :show

  # Nested class whose callbacks must NOT leak into OuterController's tree.
  class InnerController
    before_action :inner_auth, only: :show

    def show
      :inner
    end

    private

    def inner_auth
      true
    end
  end

  def show
    :outer
  end

  private

  def outer_auth
    true
  end
end
