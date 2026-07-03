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

    # Bare (and `self.`) calls dispatch through normal method lookup, so walk
    # the owner's superclass chain — inherited helpers like a parent
    # controller's `authenticate_user!` resolve too.
    def resolve_bare(call, context_owner, context_kind)
      finder = context_kind == :class_method ? :find_class_method : :find_instance_method
      find_in_chain(finder, context_owner, call.method_name)
    end

    # Resolve a call with an explicit receiver.
    def resolve_receiver(call, context_owner, context_kind, lexical_nesting)
      receiver = call.receiver

      # `SomeClass.new(...)` chain → instance method on SomeClass
      if receiver.match?(/\A([A-Z][A-Za-z0-9:]*?)\.new\z/)
        owner = receiver.sub(/\.new\z/, "")
        return resolve_constant(:instance_method, owner, call, lexical_nesting, context_owner)
      end

      # bare `new` or `self.new` chain (implicit self.new inside a class method only)
      if %w[new self.new].include?(receiver) && context_kind == :class_method
        return find_in_chain(:find_instance_method, context_owner, call.method_name)
      end

      # `SomeClass.method` → class method
      return unless receiver.match?(/\A[A-Z]/)

      resolve_constant(:class_method, receiver, call, lexical_nesting, context_owner)
    end

    def resolve_constant(kind, owner, call, lexical_nesting, context_owner)
      finder = kind == :class_method ? :find_class_method : :find_instance_method
      if call.absolute?
        find_in_chain(finder, owner, call.method_name)
      else
        find_with_namespace_fallback(finder, owner, call.method_name, lexical_nesting, context_owner)
      end
    end

    # Try the constant against each lexical scope from innermost outward
    # (mirroring Ruby's constant lookup), then against the context class's
    # superclass chain (constants nested in a parent class are visible from
    # the child), then fall back to top-level. Each scope entry is a full
    # qualified name used as a prefix directly.
    def find_with_namespace_fallback(finder, owner, method_name, lexical_nesting, context_owner)
      scopes = (lexical_nesting || []).reverse + @index.ancestor_chain(context_owner)
      scopes.each do |scope|
        result = find_in_chain(finder, "#{scope}::#{owner}", method_name)
        return result if result
      end

      find_in_chain(finder, owner, method_name)
    end

    # Method dispatch walks the receiver class's superclass chain, so a
    # method defined on a parent (class or instance side) resolves too.
    def find_in_chain(finder, owner, method_name)
      @index.ancestor_chain(owner).each do |candidate|
        result = @index.public_send(finder, candidate, method_name)
        return result if result
      end

      nil
    end
  end
end
