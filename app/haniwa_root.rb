# アプリ全体。設定は ParamStore が持ち、ここは部品を並べて保存を受け持つ。
# 最初に 1 回描くだけで、あとは各部品が自分で更新する。
class HaniwaRoot < Funicular::Component
  PRESETS = [["dancer", "「踊る人々」風"], ["warrior", "「武人」風"], ["miko", "「巫女」風"]]

  def store
    @store ||= ParamStore.new(Bridge.load_params)
  end

  def component_mounted
    store.subscribe { |params| save_later }
    # URL を貼り替えたとき (共有された URL を同じタブで開いたとき) に追従する
    JS.global.addEventListener("hashchange") do |event|
      Bridge.guard("hashchange") { store.replace(Haniwa::Params.decode(JS.global[:location][:hash].to_s)) }
    end
    Bridge.save_params(store.params)
  end

  # URL と localStorage への保存は、操作が落ち着いてからまとめて行う
  def save_later
    @save_token = (@save_token || 0) + 1
    token = @save_token
    JS.global.setTimeout(300) do
      Bridge.guard("save") { Bridge.save_params(store.params) if token == @save_token }
    end
  end

  def use_preset(name)
    Bridge.guard("preset") do
      if name == "random"
        store.replace(Haniwa::Params.random(rand(1_000_000)))
      else
        store.replace(Haniwa::Params.preset(name))
      end
    end
  end

  def render
    div(class: "layout") do
      div(class: "side") do
        div(class: "presets") do
          PRESETS.map do |preset|
            button(type: "button", id: "preset-#{preset[0]}", key: preset[0],
                   onclick: ->(e) { use_preset(preset[0]) }) { preset[1] }
          end
          button(type: "button", id: "preset-random", onclick: ->(e) { use_preset("random") }) { "ランダム" }
        end
        component(ControlPanel, preserve: true, store: store)
      end
      div(class: "main") do
        component(PreviewPane, preserve: true, store: store)
        div(class: "actions") do
          component(DownloadBar, preserve: true, store: store)
          component(ShareButton, preserve: true, store: store)
        end
        p(class: "hint") { "ドラッグで回転、ホイールで拡大・縮小。「URLを共有」で、同じ埴輪を再現できる URL を渡せます。" }
      end
    end
  end
end
