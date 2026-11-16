module Haniwa
  # 回転体としての輪郭 (高さ z に対する基本の半径)。
  # 張り出しが 45 度を超えないよう、上に向かって半径が増える所は傾きを 1 未満にしている。
  #
  # 人物埴輪の比率にならい、下から「円筒の台 → 裾 → 腰 → 肩 → 首 → 頭」と積む。
  class Profile
    attr_reader :h, :r, :hf, :z_sh, :z_nk, :z_hd, :r_neck, :r_head, :face_lo, :face_hi, :head, :body,
                :z_base, :z_waist, :r_base, :z_d, :dome_h, :z_b0, :z_b1, :rim, :r_helm,
                :z_p0, :z_p1, :plate_l, :plate_w

    TIP_RADIUS = 0.5

    def initialize(height, radius, body, head)
      @h = height.to_f
      @r = radius.to_f
      @body = body
      @head = head
      # 帽子・冠・髷のぶんだけ体と顔を低くして、全体の高さを指定どおりに保つ
      kf = 1.0
      kf = 0.86 if head == "hat"
      kf = 0.97 if head == "crown"
      kf = 0.96 if head == "shimada"
      @hf = @h * kf
      @z_base = 0.28 * @hf  # 円筒の台の上端
      @z_waist = 0.44 * @hf # 腰
      @z_sh = 0.56 * @hf    # 肩
      @z_nk = 0.61 * @hf    # 首
      @z_hd = 0.66 * @hf    # 頭の下端
      @r_neck = 0.86 * @r
      @r_head = 0.90 * @r
      @r_base = flared? ? 0.92 * @r : @r
      @r_hem = 1.18 * @r
      @r_waist = 0.96 * @r
      @z_hem = @z_base + 1.1 * (@r_hem - @r_base)
      @face_lo = @z_hd
      if head == "hat"
        @rim = 0.14 * @r
        @z_b1 = 0.90 * @hf
        @z_b0 = @z_b1 - 1.15 * @rim
        @z_b2 = @z_b1 + 0.02 * @h
        @face_hi = @z_b0
      elsif head == "crown"
        @rim = 0.12 * @r
        @z_b1 = 0.95 * @hf
        @z_b0 = @z_b1 - 1.15 * @rim
        @face_hi = @z_b0
      elsif head == "shimada"
        # 板状の髷。前後に張り出す分を、下側 45 度の斜面で支える
        @plate_l = 1.35 * @r_head
        @z_p1 = @h - 0.035 * @h
        @plate_w = 1.02 * @r_head
        # 角の丸い長方形で、中心からいちばん遠い点までの距離
        far = Math.sqrt(Math.sqrt(@plate_w * @plate_w * @plate_w * @plate_w + @plate_l * @plate_l * @plate_l * @plate_l))
        @z_p0 = @z_p1 - 1.1 * (far - @r_head)
        @face_hi = @z_p0
      elsif head == "helmet"
        # 冑。頭よりひとまわり大きい鉢を、ふちの段でかぶせる
        @rim = 0.07 * @r
        @r_helm = @r_head + @rim
        @dome_h = 0.95 * @r_helm
        @z_d = @h - @dome_h
        @z_b1 = @z_d - 0.03 * @h
        @z_b0 = @z_b1 - 1.1 * @rim
        @face_hi = @z_b0
      else
        @dome_h = 0.9 * @r_head
        @z_d = @h - @dome_h
        @face_hi = @z_d + 0.2 * @dome_h
      end
    end

    def flared?
      @body == "flared"
    end

    def dome?
      !@dome_h.nil?
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

    # まっすぐ: 一本の筒。裾広がり: 円筒の台の上に、衣の裾がかぶさる
    def body_radius(z)
      return @r unless flared?
      return @r_base if z <= @z_base
      return Haniwa.lerp(@r_base, @r_hem, (z - @z_base) / (@z_hem - @z_base)) if z <= @z_hem
      if z <= @z_waist
        return Haniwa.lerp(@r_hem, @r_waist, Haniwa.smoothstep((z - @z_hem) / (@z_waist - @z_hem)))
      end
      Haniwa.lerp(@r_waist, @r, Haniwa.smoothstep((z - @z_waist) / (@z_sh - @z_waist)))
    end

    def head_radius(z)
      if @head == "hat"
        return @r_head if z <= @z_b0
        return @r_head + @rim * (z - @z_b0) / (@z_b1 - @z_b0) if z <= @z_b1
        return @r_head + @rim if z <= @z_b2
        t = Haniwa.clamp((z - @z_b2) / (@h - @z_b2), 0.0, 1.0)
        Haniwa.lerp(@r_head + @rim, TIP_RADIUS, t)
      elsif @head == "crown"
        return @r_head if z <= @z_b0
        return @r_head + @rim * (z - @z_b0) / (@z_b1 - @z_b0) if z <= @z_b1
        @r_head + @rim
      elsif @head == "shimada"
        @r_head
      elsif @head == "helmet"
        return @r_head if z <= @z_b0
        return @r_head + @rim * (z - @z_b0) / (@z_b1 - @z_b0) if z <= @z_b1
        dome_radius(z, @r_helm)
      else
        dome_radius(z, @r_head)
      end
    end

    def dome_radius(z, full)
      return full if z <= @z_d
      t = (z - @z_d) / @dome_h
      d = 1.0 - t * t
      d = 0.0 if d < 0.0
      full * Math.sqrt(d)
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
