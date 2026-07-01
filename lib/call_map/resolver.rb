# frozen_string_literal: true

module CallMap
  # Resolves a MethodCall to a Definition using the SourceIndex.
  #
  # This handles the common Rails patterns:
  # - bare call within the same class → instance method on `context_owner`
  # - `SomeService.execute` → class method on SomeService
  # - `SomeClass.new(...).execute` → instance method on SomeClass
  # - `self.foo` → class method on `context_owner`
  class Resolver
    # @param index [SourceIndex]
    def initialize(index)
      @index = index
    end

    # @param call [MethodCall] the call to resolve
    # @param context_owner [String] the class/module the calling method belongs to
    # @return [Definition, nil]
    def resolve(call, context_owner:, context_kind: :instance_method)
      return nil if call.dynamic?

      if call.bare?
        resolve_bare(call, context_owner, context_kind)
      elsif call.receiver == "self"
        @index.find_class_method(context_owner, call.method_name)
      else
        resolve_receiver(call, context_owner)
      end
    end

    private

    def resolve_bare(call, context_owner, context_kind)
      if context_kind == :class_method
        @index.find_class_method(context_owner, call.method_name)
      else
        @index.find_instance_method(context_owner, call.method_name)
      end
    end

    # Resolve a call with an explicit receiver.
    def resolve_receiver(call, context_owner)
      receiver = call.receiver

      # `SomeClass.new(...)` chain → instance method on SomeClass
      if receiver.match?(/\A([A-Z][A-Za-z0-9:]*?)\.new\z/)
        owner = receiver.sub(/\.new\z/, "")
        return @index.find_instance_method(owner, call.method_name)
      end

      # bare `new(...)` chain (implicit self.new inside a class method)
      # → instance method on the context owner
      return @index.find_instance_method(context_owner, call.method_name) if receiver == "new"

      # `SomeClass.method` → class method
      return @index.find_class_method(receiver, call.method_name) if receiver.match?(/\A[A-Z]/)

      nil
    end
  end
end
