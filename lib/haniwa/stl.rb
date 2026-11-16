module Haniwa
  # バイナリ STL の書き出し。
  # PicoRuby の String は最大 1MB なので、小さなバイト列の配列として返す。
  module STL
    CHUNK_BYTES = 400_000

    def self.chunks(mesh, title = "HaniwaGen")
      size = Mesh::CHUNK
      parts = []
      out = title.to_s[0, 80].ljust(80, " ")
      out << [mesh.triangle_count].pack("V")
      mesh.tri_chunks.each do |tris|
        k = 0
        n = tris.size
        while k < n
          a = tris[k]
          q = a / size
          qa = q
          va = mesh.vert_values(q)
          a = (a - q * size) * 3
          b = tris[k + 1]
          q = b / size
          vb = q == qa ? va : mesh.vert_values(q)
          b = (b - q * size) * 3
          c = tris[k + 2]
          q = c / size
          vc = q == qa ? va : mesh.vert_values(q)
          c = (c - q * size) * 3
          ax = va[a]; ay = va[a + 1]; az = va[a + 2]
          bx = vb[b]; by = vb[b + 1]; bz = vb[b + 2]
          cx = vc[c]; cy = vc[c + 1]; cz = vc[c + 2]
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
          if out.bytesize >= CHUNK_BYTES
            parts << out
            out = "".dup
          end
          k += 3
        end
      end
      parts << out if out.bytesize > 0
      parts
    end

    def self.byte_size(mesh)
      84 + 50 * mesh.triangle_count
    end

    # プレビュー用: 小分けの数値配列を、それぞれ pack したバイト列にする (fmt は "e" か "V")
    def self.pack_chunks(chunks, fmt)
      parts = []
      chunks.each { |values| parts << values.pack(fmt + "*") if values.size > 0 }
      parts
    end
  end
end
