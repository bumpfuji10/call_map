# CallMap 初期設計

## 目的

CallMap は、Rails アプリケーションのコード読解を支援するための gem です。

大規模な Rails アプリケーションでは、1つの controller action の処理が、controller の private method、service object、model、policy、concern、job、PORO などに分散しがちです。

開発者がその流れを手で追うとき、Notion やノート、PR コメントなどに、ざっくりした呼び出しツリーを書きながら読んでいくことがあります。

CallMap は、その「読解用の調査メモ」を自動生成することを目指します。

完全な Ruby 静的解析器や、正確な Call Graph 生成器を目指すものではありません。

README などでは、次の姿勢を明記します。

> これは完全な静的解析器ではありません。
> 大規模 Rails アプリを読むときに、Controller action から始まる処理経路を追いやすくするための補助ツールです。

英語で説明する場合:

> This is not a perfect static analyzer.
> It helps Rails developers follow controller action call paths while reading large codebases.

## コアコンセプト

Rails の controller action、またはアプリケーション内の任意のメソッドを起点に、安定した形式で読みやすい call map を生成します。

この gem の価値は、AI より賢くコードを理解することではありません。

価値は、次のような「安定した構造化出力」にあります。

- 毎回同じ形式で出力できる
- Notion や PR コメントに貼りやすい
- 将来的に差分比較しやすい
- framework 内部ではなく、アプリケーションコードに集中できる
- コード読解用の地図として使える

## MVP のゴール

MVP は、controller action から深さ 3 程度までの呼び出しツリーを text tree で出せれば完了とします。

例:

```bash
bundle exec call_map OrdersController#destroy --depth=3
```

期待する出力イメージ:

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

## 対象範囲

CallMap は、Rails アプリケーション内の自作コードを追います。

対象に含めるもの:

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
- その他の `app/**/*.rb`
- PORO
- Concern
- Module
- Service Object
- Policy Object
- Query Object
- Form Object
- Usecase Object
- Interactor

対象外:

- Rails 本体
- Ruby 標準ライブラリ内部
- Bundler で入れた gem 内部

framework 由来の呼び出しは、葉ノードとして表示して止めてもよいです。

例:

```text
User.find [framework]
```

`ActiveRecord::FinderMethods`、Arel、Rails 内部、third-party gem の実装詳細には潜りません。

## 起点

初期 CLI の target は、次の形式を想定します。

```text
ClassName#method_name
```

MVP のユーザー向け例:

```bash
bundle exec call_map OrdersController#destroy
```

未決事項:

- public CLI として、最初から任意の `ClassName#method_name` を正式に許可するか
- それともプロダクト上は「controller action 起点」を強調しつつ、内部実装だけ任意メソッドに対応しておくか

現在の leaning:

- 内部実装は、任意の class method / instance method を起点にできる形にする
- MVP の説明では、controller action 起点を強調する

## 解析方式

MVP では静的解析を使います。

実行時トレースは初期バージョンでは対象外にします。

理由:

- 実際に Rails アプリケーションを起動する必要がある
- request setup、認証、test data、DB、credentials などに依存する
- 環境差分が大きい
- CLI として気軽に使いにくくなる

静的解析のトレードオフ:

- 任意のコードベースで実行しやすい
- 出力が安定しやすい
- 動的な Ruby の挙動は完全には解決できない
- ただし、コード読解用の補助地図としては十分に価値がある

## Parser の選択

未決事項:

- `parser` gem
- Prism

初期 leaning:

- プロトタイプでは `parser` gem が始めやすい
- 既存知見と事例が多い
- ただし parser 固有の AST 依存は狭い境界に閉じ込める
- 将来的に Prism へ差し替えられる余地を残す

実装では、parser 固有の AST node 処理をコードベース全体へ散らさないようにします。

## MVP で対応する呼び出しパターン

初期バージョンでは、次の呼び出しに対応します。

- 同一クラス内メソッド呼び出し
- private method 呼び出し
- `SomeService.execute(...)`
- `SomeClass.call(...)`
- `SomeClass.new(...).execute`
- `before_action :method_name`
- 解決可能な自作クラスの instance method
- framework っぽい呼び出しの葉ノード表示
- dynamic call の葉ノード表示

例:

```ruby
authenticate_user!
authorize_order!
OrderDeleteService.execute(order: @order)
OrderPolicy.new(current_user, @order).destroy?
OrderDeletedNotifier.call(@order)
current_user.orders.find(params[:id])
public_send(method_name)
```

出力例:

```text
public_send(method_name) [dynamic]
current_user.orders.find [framework]
```

## Rails DSL

MVP で対応したいもの:

- `before_action`

将来候補:

- `around_action`
- `after_action`
- `helper_method`
- `delegate`
- `scope`
- `included do`
- `has_many`
- `belongs_to`
- `validates`
- model callback

`before_action` は、認証、認可、事前セットアップが入ることが多いため、早めに対応する価値があります。

例:

```ruby
before_action :authenticate_user!
before_action :set_order, only: [:destroy]
```

出力例:

```text
OrdersController#destroy
├─ before_action authenticate_user!
├─ before_action set_order
└─ action body
```

## 深さ制限と循環参照

デフォルトの探索深さ:

```text
3
```

例:

```bash
bundle exec call_map OrdersController#destroy --depth=3
```

循環参照への対応:

- 訪問済みの method identifier を記録する
- 同じメソッドへ再訪したら止める
- circular として表示する

例:

```text
SomeService#execute
└─ validate!
   └─ execute [circular]
```

## 出力形式

MVP:

- text tree

将来の優先順位:

1. Markdown
2. Mermaid
3. JSON
4. HTML
5. Graphviz

理由:

- text tree は terminal で確認しやすい
- Markdown と Mermaid は Notion や PR コメントに貼りやすい
- JSON は CI、差分比較、editor integration に使いやすい

## メソッド直上コメント

CallMap は、メソッド定義の直上にあるコメントを扱えるようにします。

例:

```ruby
# 注文削除前に、削除可能な状態か検証する
def validate_deletable!
  OrderDeletionPolicy.new(@user, @order).validate!
end
```

出力案:

```text
OrderDeleteService#execute
└─ validate_deletable!
   # 注文削除前に、削除可能な状態か検証する
   └─ OrderDeletionPolicy#validate!
```

この機能は CallMap の目的に合っています。

CallMap は単なる call graph ではなく、コード読解補助ツールです。
メソッド直上コメントには、業務意図、権限、side effect、運用上の注意、domain rule が書かれていることがあります。

初期方針:

- 内部モデルでは method-leading comment を metadata として持つ
- 最初は CLI flag で opt-in 表示にする
- 長すぎるコメントは tree の視認性を落とすため、デフォルト表示は慎重に扱う

CLI 案:

```bash
bundle exec call_map OrdersController#destroy --include-comments
```

## CLI 形状

コマンド名候補:

- `call_map`
- `rails_call_map`
- `code_path`
- `method_map`
- `rails_code_path`
- `action_trace`

現在の leaning:

- Gem 名: `call_map`
- CLI コマンド: `call_map`

初期オプション:

```bash
bundle exec call_map OrdersController#destroy --depth=3
```

将来オプション:

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

## 正確性の方針

CallMap は、完璧な正確性を主張しません。

Ruby / Rails には、静的解析で完全に解決するのが難しい機能があります。

- `send`
- `public_send`
- `method_missing`
- `define_method`
- `constantize`
- `delegate`
- ActiveRecord dynamic methods
- Rails DSL
- runtime dependency injection

方針:

- よくある Rails アプリケーションの単純なパターンを解決する
- 解決できない dynamic call は隠さず表示する
- 理論的に完全な call graph より、読解に役立つ map を優先する

## テスト用 fixture app

小さな Rails 風 fixture app を用意します。

想定レイアウト:

```text
spec/fixtures/rails_app/
  app/controllers/orders_controller.rb
  app/services/order_delete_service.rb
  app/models/order.rb
  app/policies/order_policy.rb
  app/policies/order_deletion_policy.rb
  app/notifiers/order_deleted_notifier.rb
```

重要なテストケース:

- controller action body の呼び出し
- controller の private method
- `before_action`
- `before_action only: [...]`
- service `.execute`
- service `.call`
- `SomeClass.new(...).execute`
- policy method call
- framework leaf call
- dynamic call 表示
- depth limit
- circular call detection
- メソッド直上コメント

## Fixture 例

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

## 将来の auth focus

認証・認可は、call map の一部として focus 表示できます。

CLI 案:

```bash
bundle exec call_map OrdersController#destroy --focus=auth
```

出力案:

```text
OrdersController#destroy
├─ before_action authenticate_user!
├─ authorize_order!
│  └─ OrderPolicy#destroy?
└─ OrderDeleteService.execute
   └─ validate_deletable!
      └─ OrderDeletionPolicy#validate!
```

これは MVP ではなく、将来機能として扱うのがよさそうです。

## MVP でやらないこと

- 完璧な Ruby 静的解析
- 完全な call graph 生成
- Rails 内部解析
- Gem 内部解析
- Ruby 標準ライブラリ内部解析
- runtime request tracing
- model callback graph
- Concern / Module の完全な method resolution
- metaprogramming の完全対応
- Mermaid、JSON、Graphviz、HTML 出力
- VS Code extension
- CI integration

## 未決事項

1. public CLI は MVP から任意の class/method target をサポートするか
2. 最初の parser は `parser` gem か Prism か
3. ActiveRecord chain をどう表示するか
4. model method の解決にどこまで労力をかけるか
5. include された concern / module をどう解決するか
6. `around_action` と `after_action` を MVP 近くで対応するか
7. `self.execute -> new.execute` をどう表現するか
8. `send(:foo)` のような symbol literal dynamic call を解決するか
9. unresolved call の suffix は `[framework]`、`[unknown]`、なし、のどれにするか
10. auth focus を first-class feature にするか、後続の formatter/filter にするか

## 初期実装スケッチ

想定コンポーネント:

- `CallMap::CLI`
- `CallMap::SourceIndex`
- `CallMap::Definition`
- `CallMap::CallExtractor`
- `CallMap::Resolver`
- `CallMap::Analyzer`
- `CallMap::Tree`
- `CallMap::Formatters::TextTree`

大まかな流れ:

1. `app/**/*.rb` 配下の Ruby ファイルを index する
2. class / module 定義を記録する
3. instance method / class method 定義を記録する
4. メソッド直上コメントがあれば記録する
5. `before_action` から対応する Rails DSL metadata を記録する
6. 指定された target を解決する
7. target method body から呼び出しを抽出する
8. 可能なら application method へ解決する
9. framework、unknown、dynamic、depth limit、circular call で停止する
10. text tree を出力する

## 成功基準

最初の有用なバージョンでは、開発者が controller action を読むときに手で書いている call map の 70% 程度を自動生成できることを目指します。
