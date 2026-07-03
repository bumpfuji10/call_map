# CallMap

Rails アプリケーションのメソッド呼び出しチェーンを静的解析して、text tree として出力する gem です。

controller action を起点に「この action は何を呼び、その先で何が起きるのか」を、Notion や PR にそのまま貼れる形で可視化します。コードリーディングの補助ツールであり、完全な静的解析器ではありません。

## 目的

Rails アプリで処理の流れを追うとき、`destroy` action からサービス、モデル、notifier へと手でコードを辿りながらメモを書くことがあります。CallMap はその「呼び出しツリーのメモ」を自動生成します。

- framework 内部ではなく、**自分たちのアプリケーションコード**に集中する
- 出力は安定していて、ドキュメントや PR に貼れる
- `before_action` などの Rails DSL も処理経路として表示する

## インストール

現時点では RubyGems には公開していません。GitHub から直接インストールしてください。

```ruby
# Gemfile
gem "call_map", github: "bumpfuji10/call_map"
```

```bash
bundle install
```

## 使い方

Rails アプリのルートディレクトリで、`ClassName#method_name` 形式の起点を指定して実行します。

```bash
bundle exec call_map OrdersController#destroy --depth=3
```

### 出力例

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

### オプション

| オプション | 説明 |
|---|---|
| `--depth=N` | 探索の深さ制限（デフォルト: 3） |
| `--include-comments` | メソッド直上のコメントをツリーに表示する |
| `--root=PATH` | 解析対象のアプリケーションルート（デフォルト: カレントディレクトリ。`app/**/*.rb` を索引します） |

```bash
bundle exec call_map OrdersController#destroy --depth=2 --include-comments
```

### ラベルの意味

| ラベル | 意味 |
|---|---|
| `before_action foo` | `before_action` 由来の呼び出し（action 本体より前に表示） |
| `foo [framework]` | 自分のコード内に定義が見つからず、Rails / gem 側と思われる呼び出し。ここで探索を止めます |
| `foo [dynamic]` | `send` / `public_send` などの動的呼び出し。解決せず葉として表示します |
| `Foo#bar [circular]` | 探索パス上で同じメソッドに再訪した（循環）。ここで探索を止めます |
| suffix なしの未解決呼び出し | 自クラス等への呼び出しに見えるが定義を発見できなかったもの。解析漏れの可能性があるため、誤ったラベルを付けません |

## 正確性についてのスタンス

**CallMap は完全な静的解析器ではありません。** Ruby は動的な言語であり、静的解析で実行時の挙動を完全に再現することはできません。CallMap は「コードを読む人が手で書くメモ」の精度を目標にしており、以下を意図的に選択しています。

- 解決できない呼び出しは、誤って潜るのではなく**葉として止める**
- 確信の持てない呼び出しに誤ったラベルを付けない
- Rails 内部・Ruby 標準ライブラリ・gem 内部には**潜らない**（`[framework]` として表示して止まります）

## MVP で対応している呼び出しパターン

- 同一クラス内の bare call / private method（継承チェーン込み）
- `SomeService.execute` — class method
- `SomeClass.new(...).execute` / `self.new.perform` — instance method
- `self.foo` — 呼び出し元のコンテキスト（instance / class method）に応じて解決
- namespace 内の相対定数（`Reports::Runner` から `Generator.build` → `Reports::Generator.build`）、絶対定数（`::Foo`）
- 継承: 親クラスのメソッド・親クラス配下のネスト定数・superclass の lexical 解決
- `before_action` / `skip_before_action`（`only:` / `except:`、複数指定、文字列指定、継承、reopen、skip 後の再追加）
- メソッド直上コメントの保持と表示（`--include-comments`）

## Known limitations

- `around_action` / `after_action` には対応していません
- `include` / `extend` された concern / module のメソッド解決には対応していません
- メタプログラミング（`define_method`、`method_missing`、動的な定数参照など）は解決できません
- 同名メソッドが複数ある場合、Ruby の実行時ディスパッチと異なる解決をすることがあります
- 索引対象は `app/**/*.rb` のみです（`lib/` などは対象外）
- `[framework]` 判定はヒューリスティックです（receiver 付き未解決、または既知の Rails メソッド名リスト）

設計上のトレードオフの詳細は [docs/initial_design.md](docs/initial_design.md) を参照してください。

## Development

```bash
bin/setup          # 依存のインストール
bundle exec rspec  # テスト
bundle exec rubocop
bin/console        # 対話プロンプト
```

fixture の Rails アプリ（`spec/fixtures/rails_app`）に対して手元で実行できます:

```bash
ruby -Ilib exe/call_map "OrdersController#destroy" --root=spec/fixtures/rails_app
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bumpfuji10/call_map.
