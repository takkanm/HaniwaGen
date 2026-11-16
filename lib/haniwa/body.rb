module Haniwa
  # 頭と胴。半径マップ r(phi, z) から閉じたメッシュを 1 枚作る。
  # 正面は -Y、上は +Z。底は z = 0 の平面。
  module Body
    # hake_amp > 0 のとき、肩より下に縦のハケ目 (細い筋) を hake_n 本入れる
    def self.build(mesh, profile, features, nt, dz, hake_amp = 0.0, hake_n = 64)
      mesh.begin_shell("body")
      zs = profile.ring_zs(dz)
      sins = []
      coss = []
      phis = []
      hake = []
      hake_top = profile.z_sh
      hake_fade = 0.04 * profile.h
      i = 0
      while i < nt
        phi = TWO_PI * i / nt
        phis << phi
        sins << Math.sin(phi)
        coss << Math.cos(phi)
        hake << -hake_amp * 0.5 * (1.0 - Math.cos(hake_n * phi))
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
        hk = 0.0
        hk = Haniwa.clamp((hake_top - z) / hake_fade, 0.0, 1.0) if hake_amp > 0.0 && z < hake_top
        i = 0
        while i < nt
          r = base
          r += hake[i] * hk if hk > 0.0
          if na > 0
            phi = phis[i]
            k = 0
            while k < na
              r += active[k].delta(phi, z, base)
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
