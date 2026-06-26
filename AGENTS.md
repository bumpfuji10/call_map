# AGENTS.md

## プロジェクト概要

このリポジトリは、Railsアプリケーションのコード読解を支援する
Ruby gem `call_map` を開発するためのものです。

`call_map` は、Controller action またはアプリケーション内のメソッドを起点に、
呼び出し経路を読みやすいツリーとして出力することを目的とします。

完全なRuby静的解析器や、正確なCall Graph生成器を目指しません。
目的は、開発者がRailsアプリを読むときに手で書いている調査メモを、
安定した形式で自動生成することです。

主要な設計書:

- `docs/initial_design.md`

プロダクト方針やアーキテクチャ判断をする前に、この設計書を確認してください。

## 現在のフェーズ

このプロジェクトはまだ設計・プロトタイプ段階です。

アイデアを議論しているだけの場合、勝手に実装を始めないでください。
ユーザーが設計相談をしているときは、実装ではなく、設計書の更新や論点整理を優先してください。

実装を明示的に依頼された場合も、最初の実装はMVPに絞ってください。

## コア方針

- Railsアプリケーション内の自作コードを追跡する。
- Rails本体、Ruby標準ライブラリ、Bundlerで入ったGem内部には潜らない。
- 外部コードやframework由来の呼び出しは、必要に応じて葉ノードとして表示する。
- 完璧な解析より、読解に役立つ安定した出力を優先する。
- 最初の出力形式は text tree とする。
- デフォルトの探索深さは小さく保つ。現時点では `3` を想定する。
- 動的呼び出しは無理に解決せず、必要に応じて `[dynamic]` として表示する。
- メソッド直上コメントは読解上の重要な文脈なので、将来的にオプションで出力できるようにする。

## MVPスコープ

MVPで優先するもの:

- `ClassName#method_name` 形式の起点指定
- Controller action 起点
- 同一クラス内メソッド呼び出し
- private method 呼び出し
- `before_action`
- `SomeService.execute`
- `SomeClass.call`
- `SomeClass.new(...).execute`
- `app/**/*.rb` 配下の自作コード
- text tree 出力
- depth制限
- 循環参照の検出
- fixtureベースのテスト

MVPでやらないもの:

- 完璧なRuby静的解析
- 実行時リクエストトレース
- Rails内部解析
- Gem内部解析
- Ruby標準ライブラリ内部解析
- Model callback graph
- Concern / Module の完全解決
- メタプログラミングの完全対応
- Mermaid / JSON / HTML / Graphviz 出力
- VS Code拡張
- CI連携

## 設計判断のルール

新しい機能を追加する前に、次の目的に合っているか確認してください。

> Rails開発者がController actionから処理の流れを読む時間を短縮する。

この目的に直接貢献しない機能は、MVPでは後回しにしてください。

未解決の設計判断がある場合は、実装より先に `docs/initial_design.md` を更新してください。

抽象化は、MVPの複雑さを下げる場合、または設計書にある将来拡張と自然につながる場合だけ追加してください。

## Ruby / Gem 開発方針

- Ruby 3.2+ を想定する。
- RailsアプリケーションからBundler経由で使えるgemとして設計する。
- 実装クラスは `lib/call_map/` 配下に小さく分ける。
- Parser依存のAST処理は、境界を作って閉じ込める。
- `parser` gem や Prism 固有のNode処理を、コードベース全体に散らさない。
- 設計上必要になるまでは、Rails runtime への依存を追加しない。

## テスト方針

テストを追加する場合は、Rails風のfixture appを使ってください。

想定パス:

```text
spec/fixtures/rails_app/
```

優先してテストするもの:

- Controller action内の呼び出し
- private method
- `before_action`
- Service Object
- Policy
- framework leaf call
- dynamic call 表示
- depth制限
- 循環参照
- メソッド直上コメント

コード変更後は、関連するテストを実行してください。

まだテスト基盤が存在しない場合は、テストを実行したふりをせず、
「まだテスト基盤がないため未実行」と明記してください。

## ドキュメント方針

`docs/initial_design.md` をプロダクト設計の source of truth としてください。

仕様、MVP範囲、設計判断を変える場合は、実装と同じ変更内で設計書も更新してください。

READMEには将来的にユーザー向けの使い方を書きます。
設計上のトレードオフや未決事項は `docs/` に置いてください。

## Git / 作業ルール

- 開発作業を開始する場合は、必ずmainから作業ブランチを切ってから作業を開始してください。
- ユーザーが明示していない既存変更を勝手に戻さない。
- ユーザーが依頼しない限り、commit、push、branch作成はしない。
- 差分は依頼された作業に絞る。
- 実装と無関係な整形、リファクタリング、TODO削除を混ぜない。
- 設計相談中は、勝手に実装へ進まない。
