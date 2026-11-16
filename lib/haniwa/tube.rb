module Haniwa
  # 経路に沿って円を動かして作る、両端を閉じた筒 (腕に使う)
  module Tube
    def self.normalize(v)
      len = Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
      return [0.0, 0.0, 1.0] if len < 1.0e-12
      [v[0] / len, v[1] / len, v[2] / len]
    end

    def self.cross(a, b)
      [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
    end

    # 角を丸める (両端の点は動かさない)。線分の向きの範囲は元の折れ線を超えない
    def self.chaikin(pts, times)
      t = 0
      while t < times
        out = [pts[0]]
        i = 0
        while i < pts.size - 1
          p = pts[i]
          q = pts[i + 1]
          out << [0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1], 0.75 * p[2] + 0.25 * q[2]]
          out << [0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1], 0.25 * p[2] + 0.75 * q[2]]
          i += 1
        end
        out << pts[pts.size - 1]
        pts = out
        t += 1
      end
      pts
    end

    # pts: 中心の点列, radii: 各点での半径, nseg: 円の分割数
    # apex: 終端のふたの中心 (省略すると最後の点)
    def self.sweep(mesh, name, pts, radii, nseg, apex = nil)
      mesh.begin_shell(name)
      n = pts.size
      first = mesh.vertex_count
      normal = nil
      k = 0
      while k < n
        prev = pts[k > 0 ? k - 1 : 0]
        nxt = pts[k < n - 1 ? k + 1 : n - 1]
        t = normalize([nxt[0] - prev[0], nxt[1] - prev[1], nxt[2] - prev[2]])
        if normal.nil?
          seed = t[2].abs < 0.9 ? [0.0, 0.0, 1.0] : [1.0, 0.0, 0.0]
          normal = normalize(cross(seed, t))
        else
          # 前の断面の向きを引き継いで、ねじれを防ぐ
          dot = normal[0] * t[0] + normal[1] * t[1] + normal[2] * t[2]
          normal = normalize([normal[0] - dot * t[0], normal[1] - dot * t[1], normal[2] - dot * t[2]])
        end
        bin = cross(t, normal)
        p = pts[k]
        r = radii[k]
        i = 0
        while i < nseg
          a = TWO_PI * i / nseg
          ca = Math.cos(a) * r
          sa = Math.sin(a) * r
          mesh.add_vertex(p[0] + ca * normal[0] + sa * bin[0],
                          p[1] + ca * normal[1] + sa * bin[1],
                          p[2] + ca * normal[2] + sa * bin[2])
          i += 1
        end
        k += 1
      end
      p0 = pts[0]
      pe = apex.nil? ? pts[n - 1] : apex
      start_c = mesh.add_vertex(p0[0], p0[1], p0[2])
      end_c = mesh.add_vertex(pe[0], pe[1], pe[2])

      k = 0
      while k < n - 1
        row = first + k * nseg
        i = 0
        while i < nseg
          i2 = i + 1
          i2 = 0 if i2 == nseg
          a = row + i
          b = row + i2
          c = a + nseg
          d = b + nseg
          mesh.add_tri(a, b, d)
          mesh.add_tri(a, d, c)
          i += 1
        end
        k += 1
      end
      last = first + (n - 1) * nseg
      i = 0
      while i < nseg
        i2 = i + 1
        i2 = 0 if i2 == nseg
        mesh.add_tri(start_c, first + i2, first + i)
        mesh.add_tri(end_c, last + i, last + i2)
        i += 1
      end
      mesh.finish_shell
      mesh
    end
  end
end
