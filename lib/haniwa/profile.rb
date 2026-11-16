module Haniwa
  # 回転体としての輪郭 (高さ z に対する基本の半径)。
  # 張り出しが 45 度を超えないよう、上に向かって半径が増える所は傾きを 1 未満にしている。
  class Profile
    attr_reader :h, :r, :hf, :z_sh, :z_nk, :z_hd, :r_neck, :r_head, :face_lo, :face_hi, :head, :body

    TIP_RADIUS = 0.5

    def initialize(height, radius, body, head)
      @h = height.to_f
      @r = radius.to_f
      @body = body
      @head = head
      # 帽子・冠のぶんだけ体と顔を低くして、全体の高さを指定どおりに保つ
      kf = 1.0
      kf = 0.86 if head == "hat"
      kf = 0.95 if head == "crown"
      @hf = @h * kf
      @z_sh = 0.56 * @hf # 肩
      @z_nk = 0.61 * @hf # 首
      @z_hd = 0.66 * @hf # 頭の下端
      @r_neck = 0.78 * @r
      @r_head = 0.88 * @r
      @face_lo = @z_hd
      if head == "hat"
        @brim = 0.14 * @r
        @z_b1 = 0.90 * @hf
        @z_b0 = @z_b1 - 1.15 * @brim
        @z_b2 = @z_b1 + 0.02 * @h
        @face_hi = @z_b0
      elsif head == "crown"
        @brim = 0.12 * @r
        @z_b1 = 0.92 * @hf
        @z_b0 = @z_b1 - 1.15 * @brim
        @face_hi = @z_b0
      else
        @dome_h = 0.9 * @r_head
        @z_d = @h - @dome_h
        @face_hi = @z_d + 0.2 * @dome_h
      end
    end

    def dome?
      @head != "hat" && @head != "crown"
    end

    def radius(z)
      if z <= @z_sh
        body_radius(z)
      elsif z <= @z_nk
        Haniwa.lerp(@r, @r_neck, Haniwa.smoothstep((z - @z_sh) / (@z_nk - @z_sh)))
      elsif z <= @z_hd
        Haniwa.lerp(@r_neck, @r_head, Haniwa.smoothstep((z - @z_nk) / (@z_hd - @z_nk)))
      else
        head_radius(z)
      end
    end

    def body_radius(z)
      return @r if @body != "flared"
      s = 1.0 - Haniwa.clamp(z / (0.5 * @hf), 0.0, 1.0)
      @r * (1.0 + 0.38 * s * s)
    end

    def head_radius(z)
      if @head == "hat"
        return @r_head if z <= @z_b0
        return @r_head + @brim * (z - @z_b0) / (@z_b1 - @z_b0) if z <= @z_b1
        return @r_head + @brim if z <= @z_b2
        t = Haniwa.clamp((z - @z_b2) / (@h - @z_b2), 0.0, 1.0)
        Haniwa.lerp(@r_head + @brim, TIP_RADIUS, t)
      elsif @head == "crown"
        return @r_head if z <= @z_b0
        return @r_head + @brim * (z - @z_b0) / (@z_b1 - @z_b0) if z <= @z_b1
        @r_head + @brim
      else
        return @r_head if z <= @z_d
        t = (z - @z_d) / @dome_h
        d = 1.0 - t * t
        d = 0.0 if d < 0.0
        @r_head * Math.sqrt(d)
      end
    end

    # リングを置く高さの一覧。丸い頭は上へ行くほど半径の変化が急なので角度で刻む
    def ring_zs(dz)
      top = dome? ? @z_d : @h
      n = (top / dz).ceil
      n = 2 if n < 2
      zs = []
      i = 0
      while i <= n
        zs << top * i / n
        i += 1
      end
      if dome?
        m = (HALF_PI * @dome_h / dz).ceil
        m = 4 if m < 4
        i = 1
        while i < m
          zs << @z_d + @dome_h * Math.sin(HALF_PI * i / m)
          i += 1
        end
      end
      zs
    end

    def face_z(t)
      @face_lo + (@face_hi - @face_lo) * t
    end
  end
end
