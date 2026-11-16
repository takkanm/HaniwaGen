module Haniwa
  # 頭と胴。半径マップ r(phi, z) から閉じたメッシュを 1 枚作る。
  # 正面は -Y、上は +Z。底は z = 0 の平面。
  module Body
    def self.build(mesh, profile, features, nt, dz)
      mesh.begin_shell("body")
      zs = profile.ring_zs(dz)
      sins = []
      coss = []
      phis = []
      i = 0
      while i < nt
        phi = TWO_PI * i / nt
        phis << phi
        sins << Math.sin(phi)
        coss << Math.cos(phi)
        i += 1
      end

      first = mesh.vertex_count
      nf = features.size
      j = 0
      nrings = zs.size
      while j < nrings
        z = zs[j]
        base = profile.radius(z)
        active = []
        k = 0
        while k < nf
          f = features[k]
          active << f if z > f.z0 && z < f.z1
          k += 1
        end
        na = active.size
        i = 0
        while i < nt
          r = base
          if na > 0
            phi = phis[i]
            k = 0
            while k < na
              r += active[k].delta(phi, z)
              k += 1
            end
            r = 0.3 if r < 0.3
          end
          mesh.add_vertex(r * sins[i], -r * coss[i], z)
          i += 1
        end
        j += 1
      end
      bottom = mesh.add_vertex(0.0, 0.0, 0.0)
      top = mesh.add_vertex(0.0, 0.0, profile.h)

      j = 0
      while j < nrings - 1
        row = first + j * nt
        i = 0
        while i < nt
          i2 = i + 1
          i2 = 0 if i2 == nt
          a = row + i
          b = row + i2
          c = a + nt
          d = b + nt
          mesh.add_tri(a, b, d)
          mesh.add_tri(a, d, c)
          i += 1
        end
        j += 1
      end
      last = first + (nrings - 1) * nt
      i = 0
      while i < nt
        i2 = i + 1
        i2 = 0 if i2 == nt
        mesh.add_tri(bottom, first + i2, first + i)
        mesh.add_tri(top, last + i, last + i2)
        i += 1
      end
      mesh.finish_shell
      mesh
    end
  end
end
