# テスト用のメッシュ検査 (CRuby 専用)
module MeshCheck
  # 向きのついた辺ごとの出現回数を数える。
  # 水密で向きがそろっていれば、どの辺も 1 回ずつ現れ、逆向きの辺も 1 回ある。
  def self.edge_problems(mesh, tri_start = 0, tri_count = nil)
    tri_count ||= mesh.triangle_count - tri_start
    edges = Hash.new(0)
    n = mesh.vertex_count
    (tri_start...(tri_start + tri_count)).each do |t|
      a, b, c = mesh.tris[t * 3, 3]
      edges[a * n + b] += 1
      edges[b * n + c] += 1
      edges[c * n + a] += 1
    end
    bad = 0
    edges.each do |key, count|
      a = key / n
      b = key % n
      bad += 1 if count != 1 || edges.fetch(b * n + a, 0) != 1
    end
    bad
  end

  def self.each_triangle(mesh, tri_start = 0, tri_count = nil)
    tri_count ||= mesh.triangle_count - tri_start
    v = mesh.verts
    (tri_start...(tri_start + tri_count)).each do |t|
      a, b, c = mesh.tris[t * 3, 3]
      pa = v[a * 3, 3]
      pb = v[b * 3, 3]
      pc = v[c * 3, 3]
      u = [pb[0] - pa[0], pb[1] - pa[1], pb[2] - pa[2]]
      w = [pc[0] - pa[0], pc[1] - pa[1], pc[2] - pa[2]]
      nrm = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]]
      yield pa, pb, pc, nrm
    end
  end

  def self.degenerate_count(mesh)
    count = 0
    each_triangle(mesh) do |_a, _b, _c, nrm|
      count += 1 if Math.sqrt(nrm[0]**2 + nrm[1]**2 + nrm[2]**2) < 1.0e-9
    end
    count
  end

  # 底面を除き、張り出しが垂直から limit_deg 度を超える下向きの面の、面積の割合
  # inside に輪郭 (Profile) を渡すと、本体の中に埋まっている面を数えない
  def self.overhang_ratio(mesh, limit_deg, tri_start = 0, tri_count = nil, inside: nil)
    limit = -Math.sin(limit_deg * Math::PI / 180.0)
    total = 0.0
    over = 0.0
    each_triangle(mesh, tri_start, tri_count) do |a, b, c, nrm|
      len = Math.sqrt(nrm[0]**2 + nrm[1]**2 + nrm[2]**2)
      next if len < 1.0e-12
      area = len / 2.0
      total += area
      next if a[2] < 1.0e-6 && b[2] < 1.0e-6 && c[2] < 1.0e-6
      next unless nrm[2] / len < limit
      if inside
        cz = (a[2] + b[2] + c[2]) / 3.0
        rad = Math.hypot((a[0] + b[0] + c[0]) / 3.0, (a[1] + b[1] + c[1]) / 3.0)
        next if cz < inside.h && rad < inside.radius(cz)
      end
      over += area
    end
    over / total
  end
end
