# STL のダウンロード。出力用の細かいメッシュをここで作り直す。
# props: store (ParamStore)
class DownloadBar < Funicular::Component
  def initialize_state
    { busy: false, note: "" }
  end

  def download(event)
    return if state[:busy]
    patch(busy: true, note: "STL を作っています…")
    # 画面の更新を先に済ませてから、重い計算を始める
    JS.global.setTimeout(30) { Bridge.guard("export") { export } }
  end

  def export
    t0 = Bridge.now
    params = props[:store].params
    mesh = Haniwa.build(params, "export")
    name = Haniwa::Params.filename(params)
    parts = Bridge.byte_parts(Haniwa::STL.chunks(mesh, "HaniwaGen #{Haniwa::Params.summary(params)}"))
    size = Bridge.js.download(parts, name)
    sec = ((Bridge.now - t0) / 100.0).round / 10.0
    patch(busy: false, note: "#{name}（#{mesh.triangle_count} 三角形・#{(size / 1024.0 / 1024.0).round(1)} MB・#{sec} 秒）")
  rescue Exception => e
    patch(busy: false, note: "STL を作れませんでした: #{e.message}")
  end

  def render
    div(class: "download") do
      button(type: "button", id: "download", class: "primary", disabled: state[:busy], onclick: :download) do
        state[:busy] ? "生成中…" : "STLをダウンロード"
      end
      span(class: "download-note", id: "download-note") { state[:note] }
    end
  end
end
