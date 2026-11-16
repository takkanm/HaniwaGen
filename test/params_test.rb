require_relative "test_helper"

class ParamsTest < Minitest::Test
  P = Haniwa::Params

  def test_defaults_cover_every_key
    assert_equal P::SPECS.map(&:first), P.defaults.keys
    assert_equal 80, P.defaults["h"]
  end

  def test_encode_decode_roundtrip
    [P.defaults, P.preset("dancer"), P.preset("warrior"), P.preset("miko"), P.random(7)].each do |params|
      assert_equal params, P.decode("#" + P.encode(params))
    end
  end

  def test_decode_repairs_bad_input
    params = P.decode("#h=999&eye=laser&g=-5&unknown=1&&x")
    assert_equal 150, params["h"]
    assert_equal "almond", params["eye"]
    assert_equal 0, params["g"]
    assert_equal P.defaults.keys, params.keys
    assert_equal P.defaults, P.decode("")
    assert_equal P.defaults, P.decode(nil)
  end

  def test_random_is_reproducible_and_valid
    assert_equal P.random(42), P.random(42)
    refute_equal P.random(1), P.random(2)
    50.times { |seed| assert_equal P.random(seed), P.normalize(P.random(seed)) }
  end

  def test_presets_differ
    assert_equal 3, %w[dancer warrior miko].map { |n| P.preset(n) }.uniq.size
  end

  def test_filename_contains_summary
    assert_equal "haniwa-h80-round-almond-round-none.stl", P.filename(P.defaults)
  end
end
