module Haniwa
  # 埴輪の設定。キーは URL のハッシュにそのまま使うので短くしている。
  # 値は整数か文字列だけ。
  module Params
    # [キー, 種類, 初期値, 範囲または選択肢]
    SPECS = [
      ["h", "int", 80, [50, 150]],
      ["g", "int", 50, [0, 100]],
      ["body", "enum", "straight", ["straight", "flared"]],
      ["taga", "int", 1, [0, 3]],
      ["head", "enum", "round", ["round", "hat", "crown", "mizura"]],
      ["eye", "enum", "almond", ["almond", "round", "slit", "smile"]],
      ["es", "int", 50, [0, 100]],
      ["ey", "int", 50, [0, 100]],
      ["eg", "int", 50, [0, 100]],
      ["mouth", "enum", "round", ["round", "oval", "open", "frown"]],
      ["ms", "int", 50, [0, 100]],
      ["my", "int", 50, [0, 100]],
      ["nose", "enum", "small", ["none", "small", "high"]],
      ["arms", "enum", "none", ["none", "both", "one", "hips", "chest"]],
      ["neck", "int", 0, [0, 1]],
      ["tasuki", "int", 0, [0, 1]],
      ["belt", "int", 0, [0, 1]],
      ["armor", "int", 0, [0, 1]]
    ]

    PRESETS = {
      "dancer" => { "h" => 80, "g" => 40, "body" => "straight", "taga" => 1, "head" => "round",
                    "eye" => "round", "es" => 45, "ey" => 50, "eg" => 55,
                    "mouth" => "round", "ms" => 45, "my" => 50, "nose" => "small", "arms" => "one" },
      "warrior" => { "h" => 100, "g" => 60, "body" => "flared", "taga" => 0, "head" => "hat",
                     "eye" => "almond", "es" => 50, "ey" => 50, "eg" => 50,
                     "mouth" => "oval", "ms" => 40, "my" => 50, "nose" => "high", "arms" => "hips",
                     "belt" => 1, "armor" => 1 },
      "miko" => { "h" => 90, "g" => 50, "body" => "flared", "taga" => 0, "head" => "crown",
                  "eye" => "almond", "es" => 55, "ey" => 50, "eg" => 50,
                  "mouth" => "round", "ms" => 30, "my" => 50, "nose" => "small", "arms" => "chest",
                  "neck" => 1, "tasuki" => 1 }
    }

    def self.defaults
      out = {}
      SPECS.each { |s| out[s[0]] = s[2] }
      out
    end

    def self.spec(key)
      SPECS.each { |s| return s if s[0] == key }
      nil
    end

    # 範囲外や未知の値を初期値・上下限に直した、完全な設定を返す
    def self.normalize(input)
      out = {}
      SPECS.each do |s|
        key = s[0]
        v = input[key]
        if v.nil?
          out[key] = s[2]
        elsif s[1] == "int"
          out[key] = Haniwa.clamp(v.to_i, s[3][0], s[3][1])
        else
          out[key] = s[3].include?(v.to_s) ? v.to_s : s[2]
        end
      end
      out
    end

    def self.preset(name)
      normalize(PRESETS[name] || {})
    end

    def self.encode(params)
      parts = []
      SPECS.each { |s| parts << "#{s[0]}=#{params[s[0]]}" }
      parts.join("&")
    end

    # "#h=80&eye=round" のような文字列から設定を作る。壊れた値は初期値になる
    def self.decode(text)
      raw = {}
      str = text.to_s
      str = str[1, str.size - 1] if str.size > 0 && str[0] == "#"
      str.to_s.split("&").each do |pair|
        kv = pair.split("=")
        raw[kv[0]] = kv[1] if kv.size == 2 && !spec(kv[0]).nil?
      end
      normalize(raw)
    end

    def self.random(seed)
      rng = Rng.new(seed)
      out = {}
      SPECS.each do |s|
        key = s[0]
        if s[1] == "enum"
          out[key] = rng.pick(s[3])
        elsif key == "h"
          out[key] = rng.int(60, 120)
        elsif s[3][1] == 100
          out[key] = rng.int(20, 80)
        elsif s[3][1] == 1
          out[key] = rng.int(0, 2) == 0 ? 1 : 0
        else
          out[key] = rng.int(s[3][0], s[3][1])
        end
      end
      out
    end

    # ファイル名に入れる設定の要約
    def self.summary(params)
      "h#{params['h']}-#{params['head']}-#{params['eye']}-#{params['mouth']}-#{params['arms']}"
    end

    def self.filename(params)
      "haniwa-#{summary(params)}.stl"
    end
  end
end
