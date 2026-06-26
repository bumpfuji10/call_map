# CallMap Initial Design

## Purpose

CallMap is a Rails code-reading aid.

Large Rails applications often spread one controller action across private
controller methods, service objects, models, policies, concerns, jobs, and POROs.
When developers read that flow by hand, they often create a rough call tree in a
notebook, Notion, or a pull request comment.

CallMap aims to generate that rough call tree automatically.

It is not intended to be a perfect Ruby static analyzer or a complete call graph
generator.

> This is not a perfect static analyzer.
> It helps Rails developers follow controller action call paths while reading
> large codebases.

Japanese wording for README or docs:

> これは完全な静的解析器ではありません。
> 大規模Railsアプリを読むときに、Controller actionから始まる処理経路を追いやすくするための補助ツールです。

## Core Concept

Generate a stable, readable, paste-friendly call map from a Rails controller
action or another application method.

The value is not smarter reasoning than an AI assistant. The value is stable
structured output:

- Same format every time
- Easy to paste into Notion or pull request comments
- Easy to diff later
- Focused on application code, not framework internals
- Useful as a code-reading map

## MVP Goal

The MVP is complete when the gem can generate a text tree from a controller
action to depth 3.

Example:

```bash
bundle exec call_map OrdersController#destroy --depth=3
```

Expected style:

```text
OrdersController#destroy
├─ before_action authenticate_user!
├─ before_action set_order
│  └─ current_user.orders.find [framework]
├─ authorize_order!
│  └─ OrderPolicy#destroy?
├─ OrderDeleteService.execute
│  └─ OrderDeleteService#execute
│     ├─ validate_deletable!
│     │  └─ OrderDeletionPolicy#validate!
│     ├─ destroy_order!
│     │  └─ @order.destroy! [framework]
│     └─ notify_deleted
│        └─ OrderDeletedNotifier.call
└─ redirect_to [framework]
```

## Scope

CallMap follows application code.

Included:

- `app/controllers`
- `app/models`
- `app/services`
- `app/policies`
- `app/forms`
- `app/interactors`
- `app/queries`
- `app/jobs`
- `app/workers`
- `app/lib`
- Other `app/**/*.rb` files
- POROs
- Concerns
- Modules
- Service objects
- Policy objects
- Query objects
- Form objects
- Usecase objects
- Interactors

Excluded:

- Rails internals
- Ruby standard library internals
- Bundled gem internals

Framework calls may be displayed as leaf nodes.

Example:

```text
User.find [framework]
```

CallMap should not descend into `ActiveRecord::FinderMethods`, Arel, Rails, or
third-party gem implementation details.

## Starting Point

Initial CLI target:

```text
ClassName#method_name
```

MVP user-facing example:

```bash
bundle exec call_map OrdersController#destroy
```

Open design question:

- Should the CLI officially support any `ClassName#method_name` from the start?
- Or should the product language say "controller action first" while the internal
  implementation already supports any class method?

Current leaning:

- Internal implementation should support any class or instance method target.
- MVP documentation should emphasize controller actions.

## Analysis Strategy

MVP should use static analysis.

Runtime tracing is intentionally out of scope for the first version because it
requires a runnable Rails environment, test data, request setup, authentication,
and environment-specific behavior.

Static analysis tradeoff:

- Easier to run on any codebase
- More deterministic output
- Cannot fully resolve dynamic Ruby behavior
- Good enough for a code-reading map

## Parser Choice

Open question:

- `parser` gem
- `Prism`

Initial leaning:

- Use `parser` gem for the first prototype because examples and ecosystem
  knowledge are mature.
- Keep the parser boundary isolated so Prism can be considered later.

The implementation should avoid leaking parser-specific AST details throughout
the codebase.

## Call Patterns for MVP

The first version should handle:

- Same-class method calls
- Private method calls
- `SomeService.execute(...)`
- `SomeClass.call(...)`
- `SomeClass.new(...).execute`
- `before_action :method_name`
- Application class instance methods when resolvable
- Framework-like calls as leaf nodes
- Dynamic calls as leaf nodes with `[dynamic]`

Examples:

```ruby
authenticate_user!
authorize_order!
OrderDeleteService.execute(order: @order)
OrderPolicy.new(current_user, @order).destroy?
OrderDeletedNotifier.call(@order)
current_user.orders.find(params[:id])
public_send(method_name)
```

Possible output:

```text
public_send(method_name) [dynamic]
current_user.orders.find [framework]
```

## Rails DSL

MVP should support:

- `before_action`

Later candidates:

- `around_action`
- `after_action`
- `helper_method`
- `delegate`
- `scope`
- `included do`
- `has_many`
- `belongs_to`
- `validates`
- Model callbacks

`before_action` matters early because authentication, authorization, and setup
logic often live there.

Example:

```ruby
before_action :authenticate_user!
before_action :set_order, only: [:destroy]
```

Possible output:

```text
OrdersController#destroy
├─ before_action authenticate_user!
├─ before_action set_order
└─ action body
```

## Depth and Cycles

Default depth:

```text
3
```

Example:

```bash
bundle exec call_map OrdersController#destroy --depth=3
```

Cycle handling:

- Track visited method identifiers.
- Stop when the same method is reached again.
- Mark the node as circular.

Example:

```text
SomeService#execute
└─ validate!
   └─ execute [circular]
```

## Output Formats

MVP:

- Text tree

Likely later order:

1. Markdown
2. Mermaid
3. JSON
4. HTML
5. Graphviz

Reasoning:

- Text tree is easiest to inspect in a terminal.
- Markdown and Mermaid are useful for Notion and pull requests.
- JSON is useful for CI, diffing, and editor integrations.

## Method Comments

CallMap should be able to include comments immediately above a method
definition.

Example:

```ruby
# 注文削除前に、削除可能な状態か検証する
def validate_deletable!
  OrderDeletionPolicy.new(@user, @order).validate!
end
```

Possible output:

```text
OrderDeleteService#execute
└─ validate_deletable!
   # 注文削除前に、削除可能な状態か検証する
   └─ OrderDeletionPolicy#validate!
```

This fits CallMap's purpose because the tool is a code-reading aid, not only a
call graph. Method comments often explain business intent, permissions, side
effects, operational warnings, or domain-specific rules that matter when reading
a controller action flow.

Initial policy:

- Support method-leading comments as metadata in the internal model.
- Prefer an opt-in CLI flag for rendering comments at first.
- Avoid rendering very long comments by default because they can reduce tree
  readability.

Possible CLI:

```bash
bundle exec call_map OrdersController#destroy --include-comments
```

## CLI Shape

Candidate command names:

- `call_map`
- `rails_call_map`
- `code_path`
- `method_map`
- `rails_code_path`
- `action_trace`

Current leaning:

- Gem name: `call_map`
- CLI command: `call_map`

Initial options:

```bash
bundle exec call_map OrdersController#destroy --depth=3
```

Later options:

```bash
--format=text
--format=markdown
--format=json
--format=mermaid
--include-comments
--focus=auth
--include-callbacks
--exclude-framework
```

## Accuracy Policy

CallMap should explicitly avoid claiming perfect accuracy.

Ruby and Rails features that are hard or impossible to fully resolve statically:

- `send`
- `public_send`
- `method_missing`
- `define_method`
- `constantize`
- `delegate`
- ActiveRecord dynamic methods
- Rails DSLs
- Runtime dependency injection

Policy:

- Resolve simple, common Rails application patterns.
- Display unresolved dynamic calls instead of hiding them.
- Prefer useful maps over theoretically complete call graphs.

## Fixture App for Tests

Use a small Rails-like fixture app.

Suggested layout:

```text
spec/fixtures/rails_app/
  app/controllers/orders_controller.rb
  app/services/order_delete_service.rb
  app/models/order.rb
  app/policies/order_policy.rb
  app/policies/order_deletion_policy.rb
  app/notifiers/order_deleted_notifier.rb
```

Important test cases:

- Controller action body calls
- Private controller methods
- `before_action`
- `before_action only: [...]`
- Service `.execute`
- Service `.call`
- `SomeClass.new(...).execute`
- Policy method calls
- Framework leaf calls
- Dynamic call display
- Depth limit
- Circular call detection

## Example Fixture

```ruby
class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [:destroy]

  def destroy
    authorize_order!
    OrderDeleteService.execute(order: @order, user: current_user)
    redirect_to orders_path
  end

  private

  def set_order
    @order = current_user.orders.find(params[:id])
  end

  def authorize_order!
    OrderPolicy.new(current_user, @order).destroy?
  end
end
```

```ruby
class OrderDeleteService
  def self.execute(order:, user:)
    new(order:, user:).execute
  end

  def initialize(order:, user:)
    @order = order
    @user = user
  end

  def execute
    validate_deletable!
    destroy_order!
    notify_deleted
  end

  private

  def validate_deletable!
    OrderDeletionPolicy.new(@user, @order).validate!
  end

  def destroy_order!
    @order.destroy!
  end

  def notify_deleted
    OrderDeletedNotifier.call(@order)
  end
end
```

## Future Auth Focus

Authorization and authentication can be treated as a focused view of the same
call map.

Possible CLI:

```bash
bundle exec call_map OrdersController#destroy --focus=auth
```

Possible output:

```text
OrdersController#destroy
├─ before_action authenticate_user!
├─ authorize_order!
│  └─ OrderPolicy#destroy?
└─ OrderDeleteService.execute
   └─ validate_deletable!
      └─ OrderDeletionPolicy#validate!
```

This should probably be a later feature, not part of the MVP.

## Non-Goals for MVP

- Perfect Ruby static analysis
- Complete call graph generation
- Rails internals analysis
- Gem internals analysis
- Ruby standard library internals analysis
- Runtime request tracing
- Model callback graph
- Full concern/module method resolution
- Full metaprogramming support
- Mermaid, JSON, Graphviz, or HTML output
- VS Code extension
- CI integration

## Open Questions

1. Should the public CLI support arbitrary class/method targets in the MVP?
2. Should the first parser be `parser` gem or Prism?
3. How should ActiveRecord chains be displayed?
4. How much effort should go into resolving model methods?
5. How should included concerns and modules be resolved?
6. Should `around_action` and `after_action` be supported near MVP?
7. How should `self.execute -> new.execute` be represented?
8. Should dynamic `send(:foo)` be resolved when the symbol is literal?
9. Should unresolved calls default to `[framework]`, `[unknown]`, or no suffix?
10. Should auth focus be a first-class feature or a later formatter/filter?

## Initial Implementation Sketch

Suggested components:

- `CallMap::CLI`
- `CallMap::SourceIndex`
- `CallMap::Definition`
- `CallMap::CallExtractor`
- `CallMap::Resolver`
- `CallMap::Analyzer`
- `CallMap::Tree`
- `CallMap::Formatters::TextTree`

High-level flow:

1. Build an index of application Ruby files under `app/**/*.rb`.
2. Record class/module definitions.
3. Record instance and class method definitions.
4. Record leading method comments when present.
5. Record supported Rails DSL metadata, starting with `before_action`.
6. Resolve the requested target.
7. Extract calls from the target method body.
8. Resolve calls into application methods when possible.
9. Stop at framework, unknown, dynamic, depth-limited, or circular calls.
10. Print a text tree.

## Success Criterion

The first useful version should automatically generate about 70% of the call map
that a developer would otherwise write manually while reading a controller
action.
