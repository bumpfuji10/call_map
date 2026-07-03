# CallMap

[![Gem Version](https://badge.fury.io/rb/call_map.svg)](https://rubygems.org/gems/call_map)

CallMap statically analyzes a Rails application and prints the method call chain from a controller action as a text tree.

Starting from a controller action, it visualizes "what does this action call, and what happens next" in a format you can paste directly into Notion or a pull request. It is a code-reading aid, not a complete static analyzer.

## Why

When following a flow through a Rails app, you often trace code by hand — from a `destroy` action into services, models, and notifiers — writing a rough call tree as you go. CallMap generates that "call tree memo" automatically.

- Focus on **your application code**, not framework internals
- Stable output you can paste into docs and pull requests
- Rails DSLs like `before_action` are shown as part of the execution path

## Installation

```ruby
# Gemfile
gem "call_map"
```

```bash
bundle install
```

Or install it directly:

```bash
gem install call_map
```

## Usage

Run from your Rails application root, specifying the entry point as `ClassName#method_name`:

```bash
bundle exec call_map OrdersController#destroy --depth=3
```

### Example output

```text
OrdersController#destroy
├─ before_action authenticate_user!
├─ before_action set_order
│  ├─ Order.find [framework]
│  └─ params.[] [framework]
├─ authorize [framework]
├─ OrderDeleteService.execute
│  └─ OrderDeleteService#execute
│     └─ @order.destroy! [framework]
└─ OrderNotifier.notify_deletion
   └─ OrderNotifier#send_notification
      ├─ OrderNotifier#deliver
      └─ @order.user [framework]
```

### Options

| Option | Description |
|---|---|
| `--depth=N` | Maximum traversal depth (default: 3) |
| `--include-comments` | Show method leading comments in the tree |
| `--root=PATH` | Application root to analyze (default: current directory; indexes `app/**/*.rb`) |

```bash
bundle exec call_map OrdersController#destroy --depth=2 --include-comments
```

### Label reference

| Label | Meaning |
|---|---|
| `before_action foo` | A call originating from `before_action` (shown before the action body) |
| `foo [framework]` | No definition found in your code — likely Rails or a gem. Traversal stops here |
| `foo [dynamic]` | A dynamic call such as `send` / `public_send`. Left unresolved as a leaf |
| `Foo#bar [circular]` | The same method was revisited on the current path (a cycle). Traversal stops here |
| Unresolved call with no suffix | Looks like a call into your own code but no definition was found. It may be an analysis miss, so no label is attached rather than a wrong one |

## Accuracy stance

**CallMap is not a complete static analyzer.** Ruby is a dynamic language, and static analysis cannot fully reproduce runtime behavior. CallMap aims for the accuracy of "the memo a careful reader would write by hand", and makes the following deliberate choices:

- Calls that cannot be resolved **stop as leaves** instead of descending into a wrong definition
- No label is attached to a call unless there is reasonable confidence
- Rails internals, the Ruby standard library, and gem internals are **never traversed** (they appear as `[framework]` leaves)

## Supported call patterns (MVP)

- Bare calls / private methods within the same class (including the inheritance chain)
- `SomeService.execute` — class methods
- `SomeClass.new(...).execute` / `self.new.perform` — instance methods
- `self.foo` — resolved according to the calling context (instance / class method)
- Relative constants inside namespaces (`Generator.build` inside `Reports::Runner` → `Reports::Generator.build`) and absolute constants (`::Foo`)
- Inheritance: parent-class methods, constants nested in a parent class, lexical resolution of superclasses
- `before_action` / `skip_before_action` — `only:` / `except:` (symbol / string / array values), multiple filters, inheritance, reopened classes, re-adding after a skip. Filter names must be symbols (`before_action "audit"` with a string filter name is not supported)
- Method leading comments, preserved and displayed with `--include-comments`

## Known limitations

- `around_action` / `after_action` are not supported
- Method resolution through `include` / `extend` (concerns / modules) is not supported
- Metaprogramming (`define_method`, `method_missing`, dynamic constant references) cannot be resolved
- When multiple methods share a name, resolution may differ from Ruby's runtime dispatch
- Only `app/**/*.rb` is indexed (`lib/` and others are out of scope)
- `[framework]` detection is heuristic (unresolved calls with an explicit receiver, or a known Rails method name list)

See [docs/initial_design.md](docs/initial_design.md) (Japanese) for detailed design trade-offs.

## Versioning

CallMap follows [Semantic Versioning](https://semver.org/). It is currently `0.x` (MVP), so breaking changes to the output format or API may occur between minor versions.

## License

[MIT License](LICENSE.txt)

## Development

```bash
bin/setup          # install dependencies
bundle exec rspec  # run tests
bundle exec rubocop
bin/console        # interactive prompt
```

You can run against the fixture Rails app (`spec/fixtures/rails_app`) locally:

```bash
ruby -Ilib exe/call_map "OrdersController#destroy" --root=spec/fixtures/rails_app
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bumpfuji10/call_map.
