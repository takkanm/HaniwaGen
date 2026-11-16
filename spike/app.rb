# 試作: (1) スライダー/セレクト (2) Blob ダウンロード (3) 頂点計算の速度
# 本実装のコードではなく、PicoRuby.wasm + Funicular で何ができるかの確認用。

module Spike
  def self.now
    JS.global[:performance].now
  end

  # 半径マップ r(theta, z) から閉じたメッシュ(フラット配列)を作る
  def self.build_mesh(nt, nz, height, radius)
    verts = []
    tris = []
    two_pi = Math::PI * 2.0
    j = 0
    while j <= nz
      t = j.to_f / nz
      z = height * t
      base = radius * (1.0 - 0.25 * t + 0.15 * Math.sin(t * 9.0))
      i = 0
      while i < nt
        th = two_pi * i / nt
        r = base + 0.8 * Math.cos(th * 3.0) * Math.sin(t * 6.0)
        verts << r * Math.cos(th)
        verts << r * Math.sin(th)
        verts << z
        i += 1
      end
      j += 1
    end
    bottom = verts.size / 3
    verts << 0.0; verts << 0.0; verts << 0.0
    top = bottom + 1
    verts << 0.0; verts << 0.0; verts << height
    j = 0
    while j < nz
      i = 0
      row = j * nt
      while i < nt
        i2 = (i + 1) % nt
        a = row + i
        b = row + i2
        c = row + nt + i
        d = row + nt + i2
        tris << a; tris << b; tris << d
        tris << a; tris << d; tris << c
        i += 1
      end
      j += 1
    end
    i = 0
    last = nz * nt
    while i < nt
      i2 = (i + 1) % nt
      tris << bottom; tris << i2; tris << i
      tris << top; tris << last + i; tris << last + i2
      i += 1
    end
    [verts, tris]
  end

  CHUNK = 400_000 # PicoRuby の String は最大 1MB なので分割して渡す

  # 数値配列を pack して Uint8Array の JS 配列にする (fmt は "e" か "V")
  def self.pack_parts(values, fmt)
    parts = JS.global[:Array].new
    step = 30_000
    i = 0
    while i < values.size
      parts.push(JS::BLE._string_to_uint8array(values[i, step].pack(fmt + "*")))
      i += step
    end
    parts
  end

  # バイナリSTL (Array#pack 使用)。[Uint8Array の JS 配列, 総バイト数] を返す
  def self.stl_pack(verts, tris)
    n = tris.size / 3
    parts = JS.global[:Array].new
    total = 0
    out = "HaniwaGen spike".ljust(80, " ")
    out << [n].pack("V")
    k = 0
    while k < tris.size
      a = tris[k] * 3
      b = tris[k + 1] * 3
      c = tris[k + 2] * 3
      ax = verts[a]; ay = verts[a + 1]; az = verts[a + 2]
      bx = verts[b]; by = verts[b + 1]; bz = verts[b + 2]
      cx = verts[c]; cy = verts[c + 1]; cz = verts[c + 2]
      ux = bx - ax; uy = by - ay; uz = bz - az
      vx = cx - ax; vy = cy - ay; vz = cz - az
      nx = uy * vz - uz * vy
      ny = uz * vx - ux * vz
      nz = ux * vy - uy * vx
      len = Math.sqrt(nx * nx + ny * ny + nz * nz)
      if len > 0.0
        nx /= len; ny /= len; nz /= len
      end
      out << [nx, ny, nz, ax, ay, az, bx, by, bz, cx, cy, cz].pack("e12")
      out << "\x00\x00"
      if out.bytesize > CHUNK
        total += out.bytesize
        parts.push(JS::BLE._string_to_uint8array(out))
        out = ""
      end
      k += 3
    end
    total += out.bytesize
    parts.push(JS::BLE._string_to_uint8array(out))
    [parts, total]
  end

  def self.try(results, name)
    t0 = now
    begin
      v = yield
      results << "#{name}: #{v} (#{(now - t0).round(1)} ms)"
    rescue Exception => e
      results << "#{name}: ERROR #{e.class}: #{e.message}"
    end
  end

  def self.method_report
    checks = [
      ["Array", [], [:flat_map, :each_with_object, :each_slice, :each_cons, :each_with_index,
                     :inject, :reduce, :sum, :zip, :min, :max, :min_by, :max_by, :sort_by, :pack,
                     :concat, :flatten, :uniq, :group_by, :partition, :find_index, :fill, :dup,
                     :first, :last, :rotate, :reverse, :sample, :shuffle, :any?, :all?, :count,
                     :filter_map, :take, :drop, :compact, :transpose, :product, :step, :tally, :to_h]],
      ["Hash", {}, [:each_with_object, :map, :select, :reject, :merge, :fetch, :key?, :dig,
                    :to_a, :transform_values, :each_pair, :sort_by, :min_by, :find, :any?, :slice, :filter_map]],
      ["String", "", [:unpack, :unpack1, :bytes, :getbyte, :setbyte, :ljust, :rjust, :center, :split,
                      :to_f, :to_i, :to_sym, :format, :%, :start_with?, :end_with?, :gsub, :sub, :tr,
                      :each_char, :chars, :bytesize, :byteslice, :force_encoding, :b, :unpack, :ord, :hex,
                      :index, :include?, :strip, :upcase, :encoding, :freeze, :=~, :match, :scan]],
      ["Integer", 1, [:times, :upto, :downto, :step, :clamp, :to_f, :abs, :divmod, :chr, :to_s, :pow, :fdiv, :digits]],
      ["Float", 1.5, [:round, :floor, :ceil, :abs, :clamp, :to_i, :nan?, :infinite?, :truncate, :divmod]],
      ["Range", (0..1), [:each, :map, :step, :to_a, :each_with_index, :include?, :select, :inject, :sum]],
      ["Math", Math, [:sin, :cos, :tan, :atan2, :sqrt, :hypot, :exp, :log, :acos, :asin, :atan, :cbrt, :pow]],
      ["Kernel", Object.new, [:rand, :srand, :format, :sprintf, :Integer, :Float, :lambda, :proc, :loop,
                              :require, :freeze, :frozen?, :dup, :instance_variable_get, :respond_to?, :catch, :raise]]
    ]
    lines = []
    checks.each do |row|
      no = []
      row[2].each { |m| no << m unless row[1].respond_to?(m, true) }
      lines << "#{row[0]} にない: #{no.empty? ? '(なし)' : no.join(', ')}"
    end
    consts = [:Struct, :Data, :Comparable, :Enumerable, :Set, :Random, :JSON, :Base64, :Time, :Rational, :Complex, :ObjectSpace, :GC, :Regexp, :StringIO, :Marshal]
    missing = []
    consts.each { |c| missing << c unless Object.const_defined?(c) }
    lines << "定数がない: #{missing.join(', ')}"
    lines << "RUBY_ENGINE=#{RUBY_ENGINE} RUBY_VERSION=#{RUBY_VERSION}" rescue lines << "RUBY_ENGINE 不明"
    lines << "Integer max check: #{(2**30) * 4} / 1e10.to_i=#{10000000000.0.to_i}" rescue lines << "bigint ERROR"
    lines << "keyword args/Struct: #{Struct.new(:a, :b).new(1, 2).b}" rescue lines << "Struct ERROR"
    lines << "format: #{format('%.2f|%05d|%s', 3.14159, 42, :x)}" rescue lines << "format ERROR"
    lines << "pack e: #{[1.0].pack('e').bytes.inspect}" rescue lines << "pack ERROR"
    lines
  end

  def self.benchmark
    results = []
    sizes = [[48, 20], [96, 52], [160, 125]]
    sizes.each do |nt_nz|
      nt = nt_nz[0]
      nz = nt_nz[1]
      mesh = nil
      t0 = now
      mesh = build_mesh(nt, nz, 80.0, 18.0)
      t1 = now
      ntri = mesh[1].size / 3
      line = "#{ntri} 三角形: メッシュ生成 #{(t1 - t0).round(1)} ms"
      begin
        t0 = now
        f32 = JS.global[:Float32Array].new(JS::Bridge.to_js(mesh[0]))
        u32 = JS.global[:Uint32Array].new(JS::Bridge.to_js(mesh[1]))
        t1 = now
        line += " / 転送a Bridge.to_js(#{f32[:length]}, #{u32[:length]}) #{(t1 - t0).round(1)} ms"
      rescue Exception => e
        line += " / 転送a ERROR #{e.message}"
      end
      begin
        t0 = now
        f32 = JS.global[:HaniwaJS].f32(pack_parts(mesh[0], "e"))
        u32 = JS.global[:HaniwaJS].u32(pack_parts(mesh[1], "V"))
        t1 = now
        line += " / 転送b pack(#{f32[:length]}, #{u32[:length]}) #{(t1 - t0).round(1)} ms"
      rescue Exception => e
        line += " / 転送b ERROR #{e.message}"
      end
      begin
        t0 = now
        stl = stl_pack(mesh[0], mesh[1])
        t1 = now
        line += " / STL生成 #{stl[1]} bytes #{(t1 - t0).round(1)} ms #{JS.global[:HaniwaJS].stlInfo(stl[0])}"
      rescue Exception => e
        line += " / STL ERROR #{e.class} #{e.message}"
      end
      results << line
    end
    results
  end

  # バイナリ文字列を JS に渡す方法の比較
  def self.transfer_report
    results = []
    mesh = build_mesh(48, 20, 80.0, 18.0)
    stl = [0.5, 1.5, 2.5].pack("e*") * 1000
    results << "bytes=#{stl.bytesize}"
    try(results, "E: Float32Array.new(Bridge.to_js(Array))") { JS.global[:Float32Array].new(JS::Bridge.to_js([0.5, 1.5]))[:length] }
    try(results, "A: Blob.new([String]) の size") { JS.global[:Blob].new([stl])[:size] }
    try(results, "B: JS::BLE._string_to_uint8array") { JS::BLE._string_to_uint8array(stl)[:length] }
    try(results, "C: Uint8Array.new(str.bytes)") { JS.global[:Uint8Array].new(stl.bytes)[:length] }
    try(results, "D: Uint8Array.from(str.bytes)") { JS.global[:Uint8Array].from(stl.bytes)[:length] }
    results
  end
end

class SpikeApp < Funicular::Component
  EYES = [["almond", "アーモンド形"], ["round", "丸"], ["slit", "スリット"], ["smile", "三日月"]]

  def initialize_state
    { height: 80, eye: "almond", log: [], renders: 0 }
  end

  def on_height(event)
    patch(height: event[:target][:value].to_i)
  end

  def on_eye(event)
    patch(eye: event[:target][:value])
  end

  def on_methods(event)
    patch(log: Spike.method_report)
  end

  def on_bench(event)
    patch(log: Spike.benchmark)
  end

  def on_transfer(event)
    patch(log: Spike.transfer_report)
  end

  def on_download(event)
    log = []
    t0 = Spike.now
    mesh = Spike.build_mesh(96, 52, state[:height].to_f, 18.0)
    stl = Spike.stl_pack(mesh[0], mesh[1])
    name = "haniwa-h#{state[:height]}-#{state[:eye]}.stl"
    size = JS.global[:HaniwaJS].download(stl[0], name)
    log << "download: #{name} #{size} bytes (#{(Spike.now - t0).round(1)} ms)"
    patch(log: log)
  rescue Exception => e
    patch(log: ["download ERROR #{e.class}: #{e.message}"])
  end

  def render
    div do
      label do
        span { "高さ: #{state[:height]} mm " }
        input(type: "range", id: "height", min: "50", max: "150", value: state[:height].to_s, oninput: :on_height)
      end
      label do
        span { "目: " }
        select(id: "eye", onchange: :on_eye) do
          EYES.map do |pair|
            option(value: pair[0], selected: pair[0] == state[:eye], key: pair[0]) { pair[1] }
          end
        end
      end
      p(id: "summary") { "state => height=#{state[:height]} eye=#{state[:eye]}" }
      div do
        button(id: "btn-methods", onclick: :on_methods) { "メソッド確認" }
        button(id: "btn-transfer", onclick: :on_transfer) { "転送方法の比較" }
        button(id: "btn-bench", onclick: :on_bench) { "ベンチマーク" }
        button(id: "btn-download", onclick: :on_download) { "STLをダウンロード" }
      end
      tag(:pre, id: "log") { state[:log].join("\n") }
    end
  end
end

Funicular.start(SpikeApp, container: "app")
