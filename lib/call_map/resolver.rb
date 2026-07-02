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
    def resolve(call, context_owner:, context_kind: :instance_method, lexical_nesting: nil)
      return nil if call.dynamic?

      if call.bare? || call.receiver == "self"
        resolve_bare(call, context_owner, context_kind)
      else
        resolve_receiver(call, context_owner, context_kind, lexical_nesting)
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
    def resolve_receiver(call, context_owner, context_kind, lexical_nesting)
      receiver = call.receiver

      # `SomeClass.new(...)` chain → instance method on SomeClass
      if receiver.match?(/\A([A-Z][A-Za-z0-9:]*?)\.new\z/)
        owner = receiver.sub(/\.new\z/, "")
        return resolve_constant(:instance_method, owner, call, lexical_nesting)
      end

      # bare `new` or `self.new` chain (implicit self.new inside a class method only)
      if %w[new self.new].include?(receiver) && context_kind == :class_method
        return @index.find_instance_method(context_owner, call.method_name)
      end

      # `SomeClass.method` → class method
      return resolve_constant(:class_method, receiver, call, lexical_nesting) if receiver.match?(/\A[A-Z]/)

      nil
    end

    def resolve_constant(kind, owner, call, lexical_nesting)
      if call.absolute?
        finder = kind == :class_method ? :find_class_method : :find_instance_method
        @index.public_send(finder, owner, call.method_name)
      else
        find_with_namespace_fallback(kind, owner, call.method_name, lexical_nesting)
      end
    end

    # Try the constant against each lexical scope from innermost outward
    # (mirroring Ruby's constant lookup), then fall back to top-level. Each
    # nesting entry is a scope's full qualified name and is used as a prefix
    # directly, so a compact-style scope never exposes its path segments.
    def find_with_namespace_fallback(kind, owner, method_name, lexical_nesting)
      finder = kind == :class_method ? :find_class_method : :find_instance_method

      (lexical_nesting || []).reverse_each do |scope|
        result = @index.public_send(finder, "#{scope}::#{owner}", method_name)
        return result if result
      end

      @index.public_send(finder, owner, method_name)
    end
  end
end
