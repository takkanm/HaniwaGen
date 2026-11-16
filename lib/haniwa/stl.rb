module Haniwa
  # バイナリ STL の書き出し。
  # PicoRuby の String は最大 1MB なので、小さなバイト列の配列として返す。
  module STL
    CHUNK_BYTES = 400_000

    def self.chunks(mesh, title = "HaniwaGen")
      verts = mesh.verts
      tris = mesh.tris
      parts = []
      out = title.to_s[0, 80].ljust(80, " ")
      out << [mesh.triangle_count].pack("V")
      k = 0
      n = tris.size
      while k < n
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
        if out.bytesize >= CHUNK_BYTES
          parts << out
          out = "".dup
        end
        k += 3
      end
      parts << out if out.bytesize > 0
      parts
    end

    def self.byte_size(mesh)
      84 + 50 * mesh.triangle_count
    end

    # プレビュー用: 数値配列を pack したバイト列の配列にする (fmt は "e" か "V")
    def self.pack_chunks(values, fmt)
      parts = []
      step = 30_000
      i = 0
      n = values.size
      while i < n
        parts << values[i, step].pack(fmt + "*")
        i += step
      end
      parts
    end
  end
end
