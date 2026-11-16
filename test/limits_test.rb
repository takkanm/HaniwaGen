require_relative "test_helper"

# PicoRuby.wasm の上限 (Array は 131072 要素、String は 1MB) を超えないことを確かめる
class LimitsTest < Minitest::Test
  ARRAY_MAX = 131_072
  STRING_MAX = 1_048_576

  def test_export_mesh_stays_within_picoruby_limits
    params = { "h" => 150, "g" => 100, "arms" => "both", "neck" => 1, "tasuki" => 1, "belt" => 1, "armor" => 1, "taga" => 3 }
    mesh = Haniwa.build(params, "export")
    assert_operator mesh.triangle_count, :>, 150_000
    mesh.tri_chunks.each { |chunk| assert_operator chunk.size, :<=, ARRAY_MAX / 2 }
    mesh.vert_parts.each { |part| assert_operator part.bytesize, :<=, STRING_MAX / 2 }
    assert_equal mesh.vertex_count * 12, mesh.vert_parts.sum(&:bytesize)

    stl = Haniwa::STL.chunks(mesh)
    stl.each { |part| assert_operator part.bytesize, :<=, STRING_MAX / 2 }
    packed = Haniwa::STL.pack_chunks(mesh.tri_chunks, "V")
    packed.each { |part| assert_operator part.bytesize, :<=, STRING_MAX / 2 }
  end

  def test_chunked_storage_roundtrip
    mesh = Haniwa::Mesh.new
    25_000.times { |i| mesh.add_vertex(i, i + 0.5, -i) }
    25_000.times { |i| mesh.add_tri(i, (i + 1) % 25_000, (i + 2) % 25_000) }
    assert_equal 3, mesh.vert_parts.size
    assert_equal [12_345, 12_345.5, -12_345], mesh.vertex(12_345)
    assert_equal [20_000, 20_001, 20_002], mesh.triangle(20_000)
    assert_equal [24_999, 0, 1], mesh.triangle(24_999)
    assert_equal 25_000, mesh.vertex_count
    assert_equal 25_000, mesh.triangle_count
  end
end
