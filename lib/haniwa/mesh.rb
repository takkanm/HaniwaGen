module Haniwa
  # 三角形メッシュ。頂点も三角形もフラットな配列で持つ
  # (verts = [x0, y0, z0, x1, ...], tris = [a0, b0, c0, a1, ...])。
  # 本体・腕など、閉じたソリッドごとに「シェル」として範囲を記録する。
  class Mesh
    attr_reader :verts, :tris, :shells

    def initialize
      @verts = []
      @tris = []
      @shells = []
    end

    def add_vertex(x, y, z)
      @verts << x
      @verts << y
      @verts << z
      @verts.size / 3 - 1
    end

    def add_tri(a, b, c)
      @tris << a
      @tris << b
      @tris << c
    end

    def vertex_count
      @verts.size / 3
    end

    def triangle_count
      @tris.size / 3
    end

    # 新しいシェルを始める。以降に足した三角形はこのシェルに入る
    def begin_shell(name)
      finish_shell
      @shells << [name, triangle_count, 0]
    end

    def finish_shell
      return if @shells.empty?
      last = @shells[@shells.size - 1]
      last[2] = triangle_count - last[1]
    end

    # [minx, miny, minz, maxx, maxy, maxz]
    def bbox
      b = [1.0e30, 1.0e30, 1.0e30, -1.0e30, -1.0e30, -1.0e30]
      i = 0
      n = @verts.size
      while i < n
        k = 0
        while k < 3
          v = @verts[i + k]
          b[k] = v if v < b[k]
          b[k + 3] = v if v > b[k + 3]
          k += 1
        end
        i += 3
      end
      b
    end

    # 符号付き体積。法線が外向きなら正になる
    def signed_volume(tri_start = 0, tri_count = nil)
      tri_count = triangle_count - tri_start if tri_count.nil?
      vol = 0.0
      k = tri_start * 3
      last = (tri_start + tri_count) * 3
      while k < last
        a = @tris[k] * 3
        b = @tris[k + 1] * 3
        c = @tris[k + 2] * 3
        ax = @verts[a]; ay = @verts[a + 1]; az = @verts[a + 2]
        bx = @verts[b]; by = @verts[b + 1]; bz = @verts[b + 2]
        cx = @verts[c]; cy = @verts[c + 1]; cz = @verts[c + 2]
        vol += ax * (by * cz - bz * cy) + ay * (bz * cx - bx * cz) + az * (bx * cy - by * cx)
        k += 3
      end
      vol / 6.0
    end
  end
end
