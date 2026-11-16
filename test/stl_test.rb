require_relative "test_helper"

class StlTest < Minitest::Test
  def test_binary_layout
    mesh = Haniwa.build(Haniwa::Params.preset("dancer"))
    parts = Haniwa::STL.chunks(mesh)
    data = parts.join
    assert_equal Haniwa::STL.byte_size(mesh), data.bytesize
    assert_equal mesh.triangle_count, data[80, 4].unpack1("V")
    parts.each { |part| assert_operator part.bytesize, :<, 1_000_000 }

    # 最初の三角形の法線と頂点
    values = data[84, 48].unpack("e12")
    assert_in_delta mesh.vertex(mesh.triangle(0)[0])[0], values[3], 1.0e-4
    assert_in_delta 1.0, Math.sqrt(values[0]**2 + values[1]**2 + values[2]**2), 1.0e-5
  end

  def test_large_mesh_is_split_into_chunks
    mesh = Haniwa.build({}, "export")
    parts = Haniwa::STL.chunks(mesh)
    assert_operator parts.size, :>, 5
    assert_equal Haniwa::STL.byte_size(mesh), parts.sum(&:bytesize)
  end

  def test_pack_chunks
    chunks = [[0.5, 1.5, 2.5], [], [3.5]]
    parts = Haniwa::STL.pack_chunks(chunks, "e")
    assert_equal 2, parts.size
    assert_equal [0.5, 1.5, 2.5, 3.5], parts.join.unpack("e*")
  end
end
