# 形状生成の共通関数。PicoRuby と CRuby の両方で動く書き方に限る
# (while ループと基本的な Array/Hash 操作だけを使う)。
module Haniwa
  PI = 3.141592653589793
  TWO_PI = 6.283185307179586
  HALF_PI = 1.5707963267948966

  def self.clamp(v, lo, hi)
    return lo if v < lo
    return hi if v > hi
    v
  end

  def self.lerp(a, b, t)
    a + (b - a) * t
  end

  # 0..1 に丸めたうえでなめらかに補間する。傾きの最大は 1.5
  def self.smoothstep(t)
    return 0.0 if t <= 0.0
    return 1.0 if t >= 1.0
    t * t * (3.0 - 2.0 * t)
  end

  # 角度の差を -PI..PI に直す
  def self.wrap(a)
    while a > PI
      a -= TWO_PI
    end
    while a < -PI
      a += TWO_PI
    end
    a
  end

  def self.max2(a, b)
    a > b ? a : b
  end

  def self.min2(a, b)
    a < b ? a : b
  end

  # 再現できる簡単な乱数 (PicoRuby に Random/srand がないため)
  class Rng
    def initialize(seed)
      @s = seed.to_i % 233280
    end

    def next_float
      @s = (@s * 9301 + 49297) % 233280
      @s / 233280.0
    end

    def int(lo, hi)
      lo + (next_float * (hi - lo + 1)).to_i
    end

    def pick(list)
      list[int(0, list.size - 1)]
    end
  end
end
