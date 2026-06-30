# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :user

  def deletable?
    !shipped?
  end

  def shipped?
    status == "shipped"
  end
end
