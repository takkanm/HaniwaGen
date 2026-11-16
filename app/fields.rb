# 設定 1 項目ぶんの入力欄。値が変わったときは自分だけを描き直す。
# props: store (ParamStore), name (設定のキー), title (見出し)

# 選択肢 (select)
class ChoiceField < Funicular::Component
  CHOICES = {
    "body" => { "straight" => "まっすぐ（一本の筒）", "flared" => "裾広がり（台の上に衣の裾）" },
    "head" => { "round" => "丸頭", "mizura" => "みずら（肩まで垂れる髪）", "helmet" => "衝角付冑", "shimada" => "島田髷",
                "hat" => "とんがり帽子", "crown" => "平らな冠" },
    "eye" => { "almond" => "アーモンド形", "round" => "丸", "slit" => "細いスリット", "smile" => "三日月（にっこり）" },
    "mouth" => { "round" => "丸", "oval" => "横長の楕円", "open" => "大きく開いた口", "frown" => "への字" },
    "nose" => { "none" => "なし", "small" => "低い鼻筋", "high" => "高い鼻" },
    "arms" => { "none" => "なし（筒状）", "both" => "両手を上げる", "one" => "片手を上げる",
                "hips" => "腰に手を当てる", "chest" => "胸の前で手を合わせる" }
  }

  def initialize_state
    { value: props[:store].params[props[:name]] }
  end

  def component_mounted
    props[:store].subscribe { |params| follow(params[props[:name]]) }
  end

  # プリセットなど外からの変更に合わせる。
  # 一度さわった select は属性の変更だけでは表示が変わらないので、値を直接入れる
  def follow(value)
    return if value == state[:value]
    patch(value: value)
    @refs[:input][:value] = value if @refs[:input]
  end

  def on_change(event)
    value = event[:target][:value].to_s
    patch(value: value)
    props[:store].set(props[:name], value)
  end

  def render
    name = props[:name]
    label(class: "field") do
      span(class: "field-title") { props[:title] }
      select(ref: :input, id: "p-#{name}", onchange: :on_change) do
        Haniwa::Params.spec(name)[3].map do |value|
          option(value: value, selected: value == state[:value], key: value) { CHOICES[name][value] }
        end
      end
    end
  end
end

# 数値 (スライダー)
class RangeField < Funicular::Component
  def initialize_state
    { value: props[:store].params[props[:name]] }
  end

  def component_mounted
    props[:store].subscribe { |params| follow(params[props[:name]]) }
  end

  def follow(value)
    return if value == state[:value]
    patch(value: value)
    @refs[:input][:value] = value.to_s if @refs[:input]
  end

  def on_input(event)
    value = event[:target][:value].to_i
    patch(value: value)
    props[:store].set(props[:name], value)
  end

  def render
    name = props[:name]
    range = Haniwa::Params.spec(name)[3]
    label(class: "field") do
      span(class: "field-title") do
        span { props[:title] }
        span(class: "field-value") { state[:value].to_s }
      end
      input(ref: :input, type: "range", id: "p-#{name}", min: range[0].to_s, max: range[1].to_s, step: "1",
            value: state[:value].to_s, oninput: :on_input)
    end
  end
end

# あり・なし (押すたびに切り替わるボタン)
class ToggleField < Funicular::Component
  def initialize_state
    { on: props[:store].params[props[:name]] == 1 }
  end

  def component_mounted
    props[:store].subscribe { |params| follow(params[props[:name]] == 1) }
  end

  def follow(on)
    patch(on: on) if on != state[:on]
  end

  def on_click(event)
    on = !state[:on]
    patch(on: on)
    props[:store].set(props[:name], on ? 1 : 0)
  end

  def render
    button(type: "button", id: "p-#{props[:name]}", class: state[:on] ? "toggle on" : "toggle",
           "aria-pressed": state[:on] ? "true" : "false", onclick: :on_click) { props[:title] }
  end
end
