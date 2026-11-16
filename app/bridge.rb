# ブラウザ (JS) とのやり取りをまとめる。形状生成のコードからは呼ばない。
module Bridge
  STORAGE_KEY = "haniwagen.params"

  def self.js
    JS.global[:HaniwaJS]
  end

  # JS から呼ばれるブロックの中で起きた例外をコンソールに出す。
  # (そのまま投げると PicoRuby.wasm 4.0.5 では別の NameError に化けて、原因が分からなくなる)
  def self.guard(name)
    yield
  rescue Exception => e
    puts "[HaniwaGen] #{name}: #{e.class}: #{e.message}"
    nil
  end

  def self.ready?
    !JS.global[:HaniwaJS].nil?
  end

  def self.now
    JS.global[:performance].now
  end

  # バイナリ文字列を Uint8Array にする。
  # 速い内部メソッドがあれば使い、なければ数値の配列として渡す。
  def self.bytes(str)
    if @fast.nil?
      @fast = begin
        JS::BLE._string_to_uint8array("ok")[:length] == 2
      rescue Exception
        false
      end
    end
    return JS::BLE._string_to_uint8array(str) if @fast
    js.bytesFromArray(JS::Bridge.to_js(str.bytes))
  end

  # バイナリ文字列の配列を、Uint8Array の JS 配列にする
  def self.byte_parts(strings)
    parts = JS.global[:Array].new
    strings.each { |s| parts.push(bytes(s)) }
    parts
  end

  # URL のハッシュ、なければ前回の設定、どちらもなければ「踊る人々」風で始める
  def self.load_params
    hash = JS.global[:location][:hash].to_s
    return Haniwa::Params.decode(hash) if hash.size > 1
    saved = nil
    begin
      saved = JS.global[:localStorage].getItem(STORAGE_KEY)
    rescue Exception
      saved = nil
    end
    return Haniwa::Params.decode(saved) if saved.is_a?(String) && saved.size > 0
    Haniwa::Params.preset("dancer")
  end

  def self.save_params(params)
    code = Haniwa::Params.encode(params)
    JS.global[:history].replaceState(nil, "", "#" + code)
    JS.global[:localStorage].setItem(STORAGE_KEY, code)
  rescue Exception => e
    puts "設定を保存できませんでした: #{e.message}"
  end
end
