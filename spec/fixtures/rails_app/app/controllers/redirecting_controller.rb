# frozen_string_literal: true

class RedirectingController
  def cancel
    unlisted_helper
    redirect_to root_path
  end
end
