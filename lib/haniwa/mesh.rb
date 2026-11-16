module Haniwa
  # 三角形メッシュ。本体・腕など、閉じたソリッドごとに「シェル」として範囲を記録する。
  #
  # PicoRuby.wasm の事情に合わせた持ち方をしている。
  # - Array は 131072 要素までなので、頂点も三角形も CHUNK 個ずつに小分けする。
  # - Float は 1 つずつがヒープ上のオブジェクトで、大量に持ち続けると GC が遅くなる。
  #   そこで頂点は CHUNK 個たまるごとに float32 のバイト列 (String) に詰めてしまう。
  #   STL もプレビューも float32 なので、精度は変わらない。
  class Mesh
    CHUNK = 10_000 # 1 かたまりに入れる頂点数・三角形数
    CHUNK_VALUES = 30_000

    attr_reader :tri_chunks, :shells, :vertex_count, :triangle_count

    def initialize
      @vbuf = []
      @vert_packed = []
      @tcur = []
      @tri_chunks = [@tcur]
      @vertex_count = 0
      @triangle_count = 0
      @shells = []
      @cache_a = nil
      @cache_b = nil
      @cache_qa = -1
      @cache_qb = -1
    end

    def add_vertex(x, y, z)
      if @vbuf.size >= CHUNK_VALUES
        @vert_packed << @vbuf.pack("e*")
        @vbuf = []
      end
      @vbuf << x
      @vbuf << y
      @vbuf << z
      @vertex_count += 1
      @vertex_count - 1
    end

    def add_tri(a, b, c)
      if @tcur.size >= CHUNK_VALUES
        @tcur = []
        @tri_chunks << @tcur
      end
      @tcur << a
      @tcur << b
      @tcur << c
      @triangle_count += 1
    end

    # 頂点の座標を float32 (リトルエンディアン) で詰めたバイト列の配列
    def vert_parts
      return @vert_packed if @vbuf.empty?
      @vert_packed + [@vbuf.pack("e*")]
    end

    # q 番目のかたまりの座標の配列 [x0, y0, z0, x1, ...]。直近の 2 つを覚えておく
    def vert_values(q)
      return @vbuf if q == @vert_packed.size
      return @cache_a if q == @cache_qa
      if q == @cache_qb
        tmp = @cache_a
        @cache_a = @cache_b
        @cache_b = tmp
        @cache_qb = @cache_qa
        @cache_qa = q
        return @cache_a
      end
      @cache_b = @cache_a
      @cache_qb = @cache_qa
      @cache_a = @vert_packed[q].unpack("e*")
      @cache_qa = q
      @cache_a
    end

    # 頂点 i の座標 [x, y, z]
    def vertex(i)
      q = i / CHUNK
      vert_values(q)[(i - q * CHUNK) * 3, 3]
    end

    # 三角形 t の頂点番号 [a, b, c]
    def triangle(t)
      q = t / CHUNK
      @tri_chunks[q][(t - q * CHUNK) * 3, 3]
    end

    # 新しいシェルを始める。以降に足した三角形はこのシェルに入る
    def begin_shell(name)
      finish_shell
      @shells << [name, @triangle_count, 0]
    end

    def finish_shell
      return if @shells.empty?
      last = @shells[@shells.size - 1]
      last[2] = @triangle_count - last[1]
    end

    # [minx, miny, minz, maxx, maxy, maxz]
    def bbox
      b = [1.0e30, 1.0e30, 1.0e30, -1.0e30, -1.0e30, -1.0e30]
      q = 0
      while q <= @vert_packed.size
        chunk = vert_values(q)
        i = 0
        n = chunk.size
        while i < n
          k = 0
          while k < 3
            v = chunk[i + k]
            b[k] = v if v < b[k]
            b[k + 3] = v if v > b[k + 3]
            k += 1
          end
          i += 3
        end
        q += 1
      end
      b
    end

    # 符号付き体積。法線が外向きなら正になる
    def signed_volume(tri_start = 0, tri_count = nil)
      tri_count = @triangle_count - tri_start if tri_count.nil?
      vol = 0.0
      t = tri_start
      last = tri_start + tri_count
      while t < last
        tri = triangle(t)
        a = vertex(tri[0])
        b = vertex(tri[1])
        c = vertex(tri[2])
        vol += a[0] * (b[1] * c[2] - b[2] * c[1]) + a[1] * (b[2] * c[0] - b[0] * c[2]) + a[2] * (b[0] * c[1] - b[1] * c[0])
        t += 1
      end
      vol / 6.0
    end
  end
end
