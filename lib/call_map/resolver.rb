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

      if call.bare? || call.receiver == "self"
        resolve_bare(call, context_owner, context_kind)
      else
        resolve_receiver(call, context_owner, context_kind)
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
    def resolve_receiver(call, context_owner, context_kind)
      receiver = call.receiver

      # `SomeClass.new(...)` chain → instance method on SomeClass
      if receiver.match?(/\A([A-Z][A-Za-z0-9:]*?)\.new\z/)
        owner = receiver.sub(/\.new\z/, "")
        return resolve_constant(:instance_method, owner, call, context_owner)
      end

      # bare `new(...)` chain (implicit self.new inside a class method only)
      if receiver == "new" && context_kind == :class_method
        return @index.find_instance_method(context_owner, call.method_name)
      end

      # `SomeClass.method` → class method
      return resolve_constant(:class_method, receiver, call, context_owner) if receiver.match?(/\A[A-Z]/)

      nil
    end

    def resolve_constant(kind, owner, call, context_owner)
      if call.absolute?
        finder = kind == :class_method ? :find_class_method : :find_instance_method
        @index.public_send(finder, owner, call.method_name)
      else
        find_with_namespace_fallback(kind, owner, call.method_name, context_owner)
      end
    end

    def find_with_namespace_fallback(kind, owner, method_name, context_owner)
      finder = kind == :class_method ? :find_class_method : :find_instance_method
      namespace = namespace_of(context_owner)

      if namespace
        result = @index.public_send(finder, "#{namespace}::#{owner}", method_name)
        return result if result
      end

      @index.public_send(finder, owner, method_name)
    end

    def namespace_of(owner)
      return nil unless owner.include?("::")

      owner.rpartition("::").first
    end
  end
end
