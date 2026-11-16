# 3D プレビュー。メッシュは Ruby で作り、描画だけ three.js (viewer.js) に任せる。
# props: store (ParamStore)
class PreviewPane < Funicular::Component
  def component_mounted
    props[:store].subscribe { |params| schedule }
    boot
  end

  # viewer.js (ES モジュール) の読み込みを待ってから始める
  def boot
    if Bridge.ready? && @refs[:canvas]
      Bridge.js.initViewer(@refs[:canvas])
      @ready = true
      rebuild("preview")
    else
      JS.global.setTimeout(50) { Bridge.guard("boot") { boot } }
    end
  end

  # スライダーを動かしている間は、たまった変更をまとめて最後の 1 回だけ作り直す。
  # 操作中は粗いメッシュで素早く見せ、手が止まったら細かいメッシュに差し替える。
  def schedule
    return if @scheduled
    @scheduled = true
    JS.global.setTimeout(0) do
      @scheduled = false
      Bridge.guard("rebuild") { rebuild("draft") }
    end
  end

  def refine_later
    @refine_token = (@refine_token || 0) + 1
    token = @refine_token
    JS.global.setTimeout(250) do
      Bridge.guard("refine") { rebuild("preview") if token == @refine_token }
    end
  end

  def rebuild(quality)
    return unless @ready
    store = props[:store]
    code = store.code
    return if code == @built && (quality == "draft" || @built_quality == "preview")
    params = store.params
    t0 = Bridge.now
    mesh = Haniwa.build(params, quality)
    t1 = Bridge.now
    Bridge.js.setMesh(Bridge.byte_parts(mesh.vert_parts),
                      Bridge.byte_parts(Haniwa::STL.pack_chunks(mesh.tri_chunks, "V")),
                      params["h"])
    t2 = Bridge.now
    @built = code
    @built_quality = quality
    text = "プレビュー #{mesh.triangle_count} 三角形 / 生成 #{(t1 - t0).round} ms + 転送 #{(t2 - t1).round} ms"
    if quality == "preview"
      box = mesh.bbox
      @size_text = "幅 #{(box[3] - box[0]).round(1)} × 奥行 #{(box[4] - box[1]).round(1)} × 高さ #{(box[5] - box[2]).round(1)} mm　"
      text = @size_text + text
    else
      refine_later
    end
    @refs[:stats][:textContent] = text if @refs[:stats]
    schedule if store.code != code
  end

  def reset_view(event)
    Bridge.js.resetView if @ready
  end

  def render
    div(class: "preview") do
      canvas(ref: :canvas, class: "preview-canvas")
      button(type: "button", class: "ghost reset-view", onclick: :reset_view) { "視点を戻す" }
      div(ref: :stats, class: "stats")
    end
  end
end
