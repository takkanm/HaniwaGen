require_relative "test_helper"

class MeshTest < Minitest::Test
  def variations
    list = [{}]
    Haniwa::Params::PRESETS.each_key { |name| list << Haniwa::Params.preset(name) }
    # 選択肢を 1 つずつ切り替えた設定
    Haniwa::Params::SPECS.each do |key, kind, _default, range|
      values = kind == "enum" ? range : [range[0], range[1]]
      values.each { |v| list << { key => v } }
    end
    list << { "h" => 50, "g" => 0, "arms" => "both", "head" => "hat" }
    list << { "h" => 150, "g" => 100, "arms" => "both", "head" => "crown", "body" => "flared" }
    list << { "h" => 150, "g" => 100, "arms" => "chest", "neck" => 1, "tasuki" => 1, "belt" => 1, "armor" => 1, "taga" => 3 }
    list << { "h" => 50, "g" => 0, "arms" => "hips", "head" => "mizura", "es" => 0, "ms" => 0 }
    list
  end

  def test_watertight_and_consistent_winding
    variations.each do |params|
      mesh = Haniwa.build(params)
      assert_equal 0, MeshCheck.edge_problems(mesh), "辺の共有がおかしい: #{params}"
      mesh.shells.each do |name, start, count|
        assert_equal 0, MeshCheck.edge_problems(mesh, start, count), "#{name} が閉じていない: #{params}"
      end
    end
  end

  def test_normals_point_outward
    variations.each do |params|
      mesh = Haniwa.build(params)
      mesh.shells.each do |name, start, count|
        assert_operator mesh.signed_volume(start, count), :>, 0.0, "#{name} の法線が内向き: #{params}"
      end
    end
  end

  def test_body_side_normals_face_away_from_axis
    mesh = Haniwa.build(Haniwa::Params.preset("warrior"))
    _name, start, count = mesh.shells[0]
    inward = 0
    MeshCheck.each_triangle(mesh, start, count) do |a, b, c, nrm|
      cx = (a[0] + b[0] + c[0]) / 3.0
      cy = (a[1] + b[1] + c[1]) / 3.0
      next if nrm[0].abs + nrm[1].abs < 1.0e-9 # 底と天面
      inward += 1 if nrm[0] * cx + nrm[1] * cy <= 0.0
    end
    assert_equal 0, inward
  end

  def test_no_degenerate_triangles
    variations.each do |params|
      assert_equal 0, MeshCheck.degenerate_count(Haniwa.build(params)), params.to_s
    end
  end

  def test_bounding_box_matches_height
    variations.each do |params|
      full = Haniwa::Params.normalize(params)
      box = Haniwa.build(params).bbox
      assert_in_delta 0.0, box[2], 1.0e-9, "底が z=0 でない: #{params}"
      assert_in_delta full["h"], box[5], 1.0e-6, "高さが違う: #{params}"
      assert_operator box[3] - box[0], :<=, 180.0
      assert_operator box[4] - box[1], :<=, 180.0
    end
  end

  def test_plain_body_width_matches_girth
    [0, 50, 100].each do |g|
      params = { "h" => 100, "g" => g, "taga" => 0, "nose" => "none" }
      box = Haniwa.build(params).bbox
      expected = 2.0 * Haniwa::Builder.body_radius(Haniwa::Params.normalize(params))
      assert_in_delta expected, box[3] - box[0], 0.05
      assert_in_delta expected, box[4] - box[1], 0.05
    end
  end

  def test_flat_bottom
    mesh = Haniwa.build(Haniwa::Params.preset("miko"))
    flat = 0
    MeshCheck.each_triangle(mesh) do |a, b, c, nrm|
      flat += 1 if a[2] == 0.0 && b[2] == 0.0 && c[2] == 0.0 && nrm[2] < 0
    end
    assert_equal Haniwa::Builder::QUALITY["preview"][0], flat
  end

  # 顔のくぼみの天井など小さな面は 45 度を超えるので、面積の割合で見る
  def test_overhang_is_limited
    variations.each do |params|
      mesh = Haniwa.build(params, "export")
      pf = Haniwa::Builder.profile(Haniwa::Params.normalize(params))
      ratio = MeshCheck.overhang_ratio(mesh, 46.0, inside: pf)
      assert_operator ratio, :<, 0.02, "張り出しが多い (#{(ratio * 100).round(2)}%): #{params}"
    end
  end

  def test_arms_stay_within_overhang_limit
    { "both" => 0.005, "one" => 0.005, "hips" => 0.005, "chest" => 0.03 }.each do |arms, limit|
      mesh = Haniwa.build({ "arms" => arms }, "export")
      pf = Haniwa::Builder.profile(Haniwa::Params.normalize({}))
      mesh.shells[1..].each do |name, start, count|
        ratio = MeshCheck.overhang_ratio(mesh, 46.0, start, count, inside: pf)
        assert_operator ratio, :<, limit, "#{arms} の #{name}: #{(ratio * 100).round(2)}%"
      end
    end
  end

  def test_export_quality_has_more_triangles
    assert_operator Haniwa.build({}, "export").triangle_count, :>, Haniwa.build({}).triangle_count * 2
  end
end
