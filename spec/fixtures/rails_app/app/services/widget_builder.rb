# frozen_string_literal: true

class WidgetBuilder
  # `class << <object>` cannot be resolved statically, so its methods must not
  # be registered as WidgetBuilder instance methods.
  class << @registry
    def helper
      :noop
    end
  end

  # `def obj.method` with a non-constant receiver cannot be resolved statically.
  def @registry.configure
    :configure
  end
end
