# frozen_string_literal: true

class CommentedService
  # Entry point. Validates input and delegates to the worker.
  # Keep this idempotent.
  def call
    helper
  end

  x = 1 # trailing comment that must NOT attach to the next def
  def with_trailing_above
    x
  end

  # This is a deliberately long leading comment that goes far beyond sixty characters to verify truncation.
  def helper
    true
  end

  def no_comment
    true
  end
end
