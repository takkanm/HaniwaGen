# いまの設定を含む URL を共有する。
# 共有シート (Web Share API) があれば開き、なければ URL をクリップボードにコピーする。
# props: store (ParamStore)
class ShareButton < Funicular::Component
  def component_mounted
    # 共有もコピーも「クリックの処理中」にしか許されないので、
    # Funicular の onclick (あとで実行される) ではなく、同期のリスナーを直接付ける
    @refs[:button].addEventListener("click", sync: true) do |event|
      Bridge.guard("share") { share }
    end
  end

  def share
    store = props[:store]
    Bridge.save_params(store.params)
    location = JS.global[:location]
    url = "#{location[:origin]}#{location[:pathname]}##{store.code}"
    Bridge.js.share(url, "HaniwaGen で作った埴輪", @refs[:note])
  end

  def render
    span(class: "share") do
      button(ref: :button, type: "button", id: "share") { "URLを共有" }
      span(ref: :note, class: "download-note", id: "share-note")
    end
  end
end
