# パーツ選択パネル。項目ごとの入力欄を並べるだけで、自分では状態を持たない。
# props: store (ParamStore)
class ControlPanel < Funicular::Component
  GROUPS = [
    ["全体", [["h", "高さ (mm)"], ["g", "胴の太さ"]]],
    ["胴", [["body", "形"], ["taga", "突帯（タガ）の本数"]]],
    ["頭部", [["head", "形"]]],
    ["目", [["eye", "形"], ["es", "大きさ"], ["ey", "高さ"], ["eg", "間隔"]]],
    ["口", [["mouth", "形"], ["ms", "大きさ"], ["my", "高さ"]]],
    ["鼻", [["nose", "形"]]],
    ["腕", [["arms", "形"]]],
    ["装飾", [["neck", "首飾り"], ["tasuki", "たすき"], ["belt", "腰帯"], ["armor", "甲冑風の横線"]]]
  ]

  def field_class(name)
    spec = Haniwa::Params.spec(name)
    return ChoiceField if spec[1] == "enum"
    return ToggleField if spec[3][1] == 1
    RangeField
  end

  def render
    store = props[:store]
    div(class: "panel") do
      GROUPS.map do |group|
        div(class: "group", key: group[0]) do
          h2 { group[0] }
          div(class: group[0] == "装飾" ? "toggles" : "fields") do
            group[1].map do |item|
              component(field_class(item[0]), preserve: true, key: item[0], store: store, name: item[0], title: item[1])
            end
          end
        end
      end
    end
  end
end
