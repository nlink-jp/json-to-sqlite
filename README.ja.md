# json-to-sqlite

JSONデータをインテリジェントに解釈し、SQLiteデータベースに変換する柔軟なコマンドラインツールです。

このツールはテーブルスキーマを自動的に推論し、新しいカラムを追加してスキーマの変更を処理し、ファイルまたは標準入力のどちらからでもJSONを処理できるため、データ処理と永続化のための強力なユーティリティとなります。

## 主な機能

-   **自動スキーマ推論**: JSONオブジェクトの構造からSQLiteのテーブルスキーマをインテリジェントに生成します。
-   **スキーマの自動更新**: 入力データに新しいフィールドが検出されると、新しいカラムを追加して既存のテーブルをシームレスに更新します。
-   **柔軟な入力**: ファイルから、または標準入力から直接パイプで渡されたJSONデータを読み取ります。
-   **データ型マッピング**: JSONの型を適切なSQLiteの型（`TEXT`, `REAL`, `INTEGER`）に自動的にマッピングします。型が競合した場合は安全のために`TEXT`が使用されます。
-   **ネストされたJSONの処理**: ネストされたJSONオブジェクトや配列を`TEXT`カラムにシリアライズして保存します。
-   **クロスプラットフォーム**: 付属の`Makefile`により、macOS (amd64/arm64)、Linux (amd64/arm64)、Windows (amd64) 向けにビルドできます。CGO依存のため、Linux・Windows のクロスコンパイルには Podman または Docker コンテナを使用します。

## インストール

お使いのOSに対応したコンパイル済みのバイナリを[リリースページ](https://github.com/nlink-jp/json-to-sqlite/releases)からダウンロードしてください。

## 使い方

このツールは、必須のフラグ`-o`と`-t`に加えて、JSONデータを入力ファイルまたは標準入力経由で受け取ります。

-   `-o <パス>`: **必須。** 出力先のSQLiteデータベースファイルを指定します。
-   `-t <テーブル名>`: **必須。** 作成または更新するテーブル名を指定します。
-   `--version`: ツールのバージョン情報を表示します。

任意の引数 `[入力ファイル]` を指定すると、そのファイルからJSONを読み込みます。`[入力ファイル]` が省略されるか、`-` に設定された場合、ツールは標準入力から読み込みます。

### 使用例

**1. JSONファイルを新しいデータベースに変換する:**
```bash
json-to-sqlite -o users.db -t users users.json
```

**2. 他のコマンド（例: `curl`）からJSONデータをパイプで渡す:**
```bash
curl "https://api.example.com/data" | json-to-sqlite -o api_data.db -t records
```
*注: 上記のコマンドは `[入力ファイル]` 引数を省略しているため機能します。引数として `-` を使用しても (`... | json-to-sqlite -o api_data.db -t records -`) 同じ結果になります。*

**3. 新しいカラムを持つ可能性のあるデータを既存のデータベースに追加する:**
```bash
# new_users.jsonに新しいフィールドがあれば、この2回目のコマンドで'users'テーブルに新しいカラムが追加されます
json-to-sqlite -o users.db -t users new_users.json
```

## ビルド

ソースからビルドするには、GoとMakeがインストールされている必要があります。

```bash
# 1. リポジトリをクローン
git clone https://github.com/nlink-jp/json-to-sqlite.git
cd json-to-sqlite

# 2. バイナリをビルド
make build

# 実行ファイルは dist/ に生成されます
```

全プラットフォーム向けのクロスコンパイルとパッケージング（Linux/Windows ビルドには Podman または Docker が必要）:

```bash
# 全プラットフォーム向けにビルド
make build-all

# 全バイナリをビルドし、dist/ に .zip アーカイブを作成
make package
```

## 動作の詳細

### 型のマッピング
JSONの型は以下のようにSQLiteの型にマッピングされます。
-   `string` -> `TEXT`
-   `number` -> `REAL`
-   `boolean` -> `INTEGER` (`true`は1, `false`は0)
-   `array` -> `TEXT` (JSON文字列として保存)
-   `object` -> `TEXT` (JSON文字列として保存)

複数のオブジェクトで同じキーが異なるデータ型を持つ場合、全てのデータを損失なく保存するために、カラムの型は`TEXT`に昇格されます。

## ライセンス

このプロジェクトは [MITライセンス](LICENSE) の下で公開されています。
