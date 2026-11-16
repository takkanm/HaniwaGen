# HaniwaGen

顔・腕・装飾などのパーツを選んで人物埴輪をデザインし、3Dプリント用の STL をダウンロードできる Web アプリです。

- 画面とロジックは Ruby（[PicoRuby.wasm](https://github.com/picoruby/picoruby) と SPA フレームワーク [Funicular](https://github.com/picoruby/funicular)）で書いています。
- サーバは不要です。`public/` を静的サイトとして置くだけで動きます。
- 想定プリンタは Bambu Lab A1 mini（造形範囲 180×180×180 mm、ノズル 0.4 mm）です。

## ローカルで動かす

Ruby（3.2 以降）と rake があれば動きます。Node.js は不要です。

```bash
rake serve
```

http://localhost:8765 を開きます。`rake serve` は最初に `rake build` を実行します。Ruby のソースを変えたら、`rake build` をやり直してページを再読み込みしてください。

| コマンド | 内容 |
|---|---|
| `rake test` | 形状生成のテスト（CRuby + minitest） |
| `rake build` | `lib/` と `app/` の Ruby を連結して `public/app.rb` を作る |
| `rake serve` | ビルドして `public/` を配信する（`PORT` でポートを変更） |
| `rake stl` | 各プリセットの STL を `tmp/stl/` に書き出す |
| `rake stl:check` | 書き出した STL を trimesh で検査する |

## 構成

```
lib/haniwa/      形状生成（UI に依存しない純粋な Ruby。CRuby でも PicoRuby でも動く）
  profile.rb       回転体としての輪郭（裾・首・頭・帽子）
  features.rb      半径マップに足すくぼみと盛り上がり（目・口・鼻・みずら・帯・首飾り）
  body.rb          半径マップ r(φ, z) から頭と胴の閉じたメッシュを作る
  tube.rb, arms.rb 腕（経路に沿った筒。本体とは別の閉じたソリッド）
  mesh.rb, stl.rb  メッシュの入れ物とバイナリ STL の書き出し
  params.rb        設定の定義、URL 用のエンコード、プリセット、ランダム生成
  builder.rb       設定からメッシュを組み立てる入口（Haniwa.build）
app/             Funicular のコンポーネント
  param_store.rb   現在の設定を持ち、変更を知らせる
  fields.rb, control_panel.rb  パーツ選択パネル
  preview_pane.rb  3D プレビュー
  download_bar.rb  STL ダウンロード
  share_button.rb  設定を含む URL の共有
  haniwa_root.rb   全体の配置、URL と localStorage への保存
  bridge.rb        JS とのやり取り
public/          配信するファイル（index.html, viewer.js, style.css, vendor/）
sources.txt      連結する順番（ブラウザ用のビルドと CRuby のテストで共通）
test/            minitest
spike/           最初に作った試作（スライダー、Blob ダウンロード、速度計測）
```

描画とファイル保存だけを JS（`public/viewer.js`、three.js）が受け持ちます。メッシュと STL のバイト列は Ruby が作ります。

## 形状と印刷しやすさ

実物の人物埴輪に似せて、次のように作っています。

- 下から「円筒の台 → 衣の裾 → 腰 → 肩 → 首 → 頭」と積みます。台には突帯（タガ）と丸い透かし孔を付けられます。
- 目・口・透かし孔は、縁を立てて深く（2.5 mm 以上、半径の 4 割まで）へこませた「くぼみ」です。切り抜いた穴に見えますが貫通はしていないので、中実のまま水密なメッシュになります。
- 鼻は眉間から下へ伸びる稜線で、眉のひさしとつながって T 字になります。耳は小さな輪です。
- 頭部は丸頭・みずら（肩まで垂れる髪の束）・衝角付冑（衝角としころ付き）・島田髷・とんがり帽子・平らな冠から選べます。
- 表面には縦のハケ目（細い筋）を入れられます。
- 腕は細い棒で、これだけが別の閉じたソリッドです。根元を本体にめり込ませています。

サポートなしで立てて印刷できるよう、次の決まりを守っています。

- 頭と胴は 1 枚の閉じたメッシュで、顔や髪型・冑もその中で作ります。継ぎ目がなく、盛り上がりの下側を 45° の斜面にできます。
- 底は z = 0 の平面です。中は中実で、内部はスライサーのインフィルに任せます。
- 腕のうち本体の外に出る部分は、水平から 50° 以上の傾きにしています。胸の前で合わせる腕だけは、体に 8 割埋めたうえで約 39° にゆるめています（手を胸の高さに保つため）。
- くぼみの天井など小さい面は 45° を超えます。テストでは、45° を超える面が全体の面積の 2% 未満であることを条件にしています。

## 検証

`rake test` で次を確認します。

- 水密であること（どの辺もちょうど 2 つの三角形に、逆向きで共有されている）
- 法線が外向きであること（シェルごとの符号付き体積が正）
- 高さが指定どおりで底が z = 0 にあること、縮退した三角形がないこと
- 張り出しの面積比、ランダム生成 40 通り、PicoRuby の上限（配列・文字列の大きさ）

STL そのものは次の手順で検査します。

```bash
pip install trimesh numpy scipy networkx
rake stl:check
```

重なった複数のシェルを Bambu Studio が 1 つのオブジェクトとして扱えるかは、コマンドラインのスライスで確かめられます（A1 mini・0.20mm Standard・サポートなし）。3 つのプリセットとも、警告なしでスライスできることを確認済みです。

```bash
P="/Applications/BambuStudio.app/Contents/Resources/profiles/BBL"
/Applications/BambuStudio.app/Contents/MacOS/BambuStudio \
  --load-settings "$P/machine/Bambu Lab A1 mini 0.4 nozzle.json;$P/process/0.20mm Standard @BBL A1M.json" \
  --load-filaments "$P/filament/Bambu PLA Basic @BBL A1M.json" \
  --arrange 1 --slice 0 --outputdir tmp/slice --export-3mf dancer.3mf tmp/stl/dancer.stl
```

画面で確かめる場合は、STL を読み込んでスライスし、プレビューで腕の付け根が本体とつながっていること、「非多様体の辺」の警告が出ないことを見てください。

## デプロイ

### GitHub Pages

`.github/workflows/pages.yml` が、`main` への push のたびにテストとビルドを行い、`public/` を公開します。リポジトリの Settings → Pages で Source を「GitHub Actions」にしてください。

### Cloudflare Pages

- Build command: `rake build`
- Build output directory: `public`

`public/app.rb` はビルドで作るファイルなので、リポジトリには入れていません。

## PicoRuby.wasm で気をつけること

`@picoruby/wasm-wasi` 4.0.5（Funicular 同梱）を `public/vendor/picoruby/` に置いています。

- Array は 131,072 要素まで、String は 1 MB までです。メッシュは小分けの配列で持ち、STL も小さなバイト列の配列として作ります。
- Float は 1 つずつがヒープ上のオブジェクトです。頂点を float32 のバイト列に詰めて持つと、GC の時間が大きく減ります。
- `flat_map` `each_with_object` `each_slice` `sum` `zip` `sort_by` `clamp` `Struct` などがありません。`lib/haniwa/` は `while` と基本的な配列操作だけで書いています。
- バイナリを JS に渡す公開 API がないため、内部メソッド `JS::BLE._string_to_uint8array` を使っています（`app/bridge.rb` の 1 か所。なければ数値の配列で渡します）。
- 親コンポーネントを `patch` すると子も描き直され、イベントの付け直しが起きます。設定は `ParamStore` で持ち、入力欄ごとに自分だけを `patch` しています。
- JS から呼ばれるブロック（`setTimeout` など）の中で例外を投げると、別の `NameError` に化けます。`Bridge.guard` で受けてコンソールに出しています。

## ライセンス

同梱している PicoRuby.wasm と three.js は、それぞれ MIT License です（`public/vendor/` を参照）。
