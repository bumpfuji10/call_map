# frozen_string_literal: true

class SharedCallService
  def entry
    branch_a
    branch_b
  end

  def branch_a
    shared_helper
  end

  def branch_b
    shared_helper
  end

  def shared_helper
    true
  end
end
