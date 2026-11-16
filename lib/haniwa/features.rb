module Haniwa
  # 半径マップ r(phi, z) に足す「くぼみ」と「盛り上がり」。
  # どれも z0..z1 (影響する高さの範囲) と delta(phi, z, base) を持つ。
  # phi は正面を 0 とした角度、base はその高さでの輪郭の半径、
  # u は表面に沿った横方向の長さ(mm)、v は縦方向の長さ(mm)。
  #
  # 盛り上がりは、下側の斜面が 45 度より寝ないように作る (サポートなしで印刷するため)。
  module Features
    # 目・口・透かし孔。実物の切り抜きに似せて、縁を立てて深くへこませる
    class Indent
      attr_reader :z0, :z1

      # kind: "ellipse" | "almond" | "slit" | "arc"
      # a = 横の半幅, b = 縦の半幅 (arc では線の太さの半分)
      def initialize(kind, phi0, zc, a, b, rref, depth, ramp)
        @kind = kind
        @phi0 = phi0
        @zc = zc
        @a = a
        @b = b
        @rref = rref
        @depth = depth
        @ramp = ramp
        vext = b
        if kind == "almond"
          @rho = (a * a + b * b) / (2.0 * b)
          @off = @rho - b
        elsif kind == "arc"
          @amax = 1.0472 # 60度
          @rho = a / Math.sin(@amax)
          cosm = Math.cos(@amax)
          @cy = -@rho * (1.0 + cosm) / 2.0
          @ex = @rho * Math.sin(@amax)
          @ey = @rho * cosm
          vext = @rho * (1.0 - cosm) / 2.0 + b
        end
        @uext = a + b + ramp
        @z0 = zc - vext - ramp
        @z1 = zc + vext + ramp
      end

      def delta(phi, z, base)
        u = Haniwa.wrap(phi - @phi0) * @rref
        return 0.0 if u > @uext || u < -@uext
        t = (@ramp * 0.5 - sdf(u, z - @zc)) / @ramp
        return 0.0 if t <= 0.0
        -@depth * Haniwa.smoothstep(t)
      end

      # 形の内側が負になる距離
      def sdf(u, v)
        if @kind == "ellipse"
          k = Math.sqrt((u / @a) * (u / @a) + (v / @b) * (v / @b))
          (k - 1.0) * Haniwa.min2(@a, @b)
        elsif @kind == "almond"
          d1 = Math.sqrt(u * u + (v - @off) * (v - @off)) - @rho
          d2 = Math.sqrt(u * u + (v + @off) * (v + @off)) - @rho
          Haniwa.max2(d1, d2)
        elsif @kind == "slit"
          du = u.abs - (@a - @b)
          du = 0.0 if du < 0.0
          Math.sqrt(du * du + v * v) - @b
        else
          dy = v - @cy
          ang = Math.atan2(u, dy)
          if ang <= @amax && ang >= -@amax
            (Math.sqrt(u * u + dy * dy) - @rho).abs - @b
          else
            ex = u < 0 ? -@ex : @ex
            Math.sqrt((u - ex) * (u - ex) + (dy - @ey) * (dy - @ey)) - @b
          end
        end
      end
    end

    # 鼻。眉間から下へ伸びる細い稜線で、いちばん下が最も高い
    class Nose
      attr_reader :z0, :z1

      def initialize(z_tip, height, rref, above)
        @zt = z_tip
        @hn = height
        @rref = rref
        @below = 1.05 * height
        @above = Haniwa.max2(above, 1.5 * height)
        @wh = 0.55 * height + 0.4
        @z0 = z_tip - @below
        @z1 = z_tip + @above
      end

      def delta(phi, z, base)
        u = Haniwa.wrap(phi) * @rref
        return 0.0 if u > @wh || u < -@wh
        v = z - @zt
        hv = v < 0.0 ? @hn * (1.0 + v / @below) : @hn * (1.0 - v / @above)
        d = hv - u.abs * (@hn / @wh)
        d > 0.0 ? d : 0.0
      end
    end

    # 眉のひさし。鼻筋とつながって T 字になる
    class Brow
      attr_reader :z0, :z1

      def initialize(zc, span, fade, plateau, height)
        @zc = zc
        @span = span
        @fade = fade
        @half = plateau / 2.0
        @hh = height
        @below = 1.1 * height
        @above = 2.0 * height
        @z0 = zc - @half - @below
        @z1 = zc + @half + @above
      end

      def delta(phi, z, base)
        a = Haniwa.wrap(phi).abs
        return 0.0 if a >= @span + @fade
        v = z - @zc
        f = v < 0.0 ? (@half + @below + v) / @below : (@half + @above - v) / @above
        f = Haniwa.clamp(f, 0.0, 1.0)
        e = a <= @span ? 1.0 : 1.0 - (a - @span) / @fade
        @hh * f * e
      end
    end

    # 耳。小さな輪
    class Ear
      attr_reader :z0, :z1

      def initialize(phi0, zc, ring, width, height, rref)
        @phi0 = phi0
        @zc = zc
        @ring = ring
        @w = width
        @hh = height
        @rref = rref
        @ext = ring + width
        @z0 = zc - @ext
        @z1 = zc + @ext
      end

      def delta(phi, z, base)
        u = Haniwa.wrap(phi - @phi0) * @rref
        return 0.0 if u > @ext || u < -@ext
        v = z - @zc
        d = (Math.sqrt(u * u + v * v) - @ring).abs
        return 0.0 if d >= @w
        @hh * (1.0 - d / @w)
      end
    end

    # みずら (下げみずら)。こめかみから肩まで垂れる髪の束で、途中を結んである。
    # 肩の上から 45 度で立ち上がるので、下端は肩に支えられる
    class Mizura
      attr_reader :z0, :z1

      def initialize(phi0, z_bottom, z_top, r_bottom, r_full, au, rref, height)
        @phi0 = phi0
        @z0 = z_bottom
        @z1 = z_top
        @rb = r_bottom
        @rf = r_full
        @au = au
        @rref = rref
        @cap = 0.03 * height
        @ztie = z_bottom + (z_top - z_bottom) * 0.45
        @tw = 0.025 * height
      end

      def delta(phi, z, base)
        u = Haniwa.wrap(phi - @phi0) * @rref
        return 0.0 if u >= @au || u <= -@au
        target = Haniwa.min2(@rf, @rb + (z - @z0) / 1.1)
        d = target - base
        return 0.0 if d <= 0.0
        top = @z1 - @cap
        if z > top
          t = (z - top) / @cap
          d *= Math.sqrt(Haniwa.max2(0.0, 1.0 - t * t))
        end
        dv = (z - @ztie).abs
        d *= 1.0 - 0.3 * Haniwa.smoothstep(1.0 - dv / @tw) if dv < @tw
        d * Math.sqrt(1.0 - (u / @au) * (u / @au))
      end
    end

    # 衝角付冑の衝角。鉢の正面を走る稜線で、ふちの所でくちばしのように前へ出る
    class Keel
      attr_reader :z0, :z1

      def initialize(pf, height, half_angle)
        @hk = height
        @ha = half_angle
        @r_head = pf.r_head
        @r_helm = pf.r_helm
        @rim = pf.rim
        @z_b1 = pf.z_b1
        @z0 = pf.z_b1 - 1.1 * (pf.rim + height)
        @z1 = pf.h
      end

      def delta(phi, z, base)
        a = Haniwa.wrap(phi).abs
        return 0.0 if a >= @ha
        tri = 1.0 - a / @ha
        if z < @z_b1
          target = @r_head + (@rim + @hk) * (z - @z0) / (@z_b1 - @z0)
          d = target - base
          d > 0.0 ? d * tri : 0.0
        else
          @hk * (base / @r_helm) * tri
        end
      end
    end

    # 冑のしころ (首を守る垂れ)。ふちから肩まで、横と後ろを覆う
    class Shikoro
      attr_reader :z0, :z1

      def initialize(pf, phi_start)
        @z0 = pf.z_sh
        @z1 = pf.z_b1
        @rb = pf.r
        @rt = pf.r_helm
        @ps = phi_start
      end

      def delta(phi, z, base)
        b = Haniwa.smoothstep((Haniwa.wrap(phi).abs - @ps) / 0.25)
        return 0.0 if b <= 0.0
        d = Haniwa.lerp(@rb, @rt, (z - @z0) / (@z1 - @z0)) - base
        d > 0.0 ? d * b : 0.0
      end
    end

    # 島田髷。頭の上に載る前後に長い板で、中央がくびれている
    class Shimada
      attr_reader :z0, :z1

      def initialize(pf)
        @z0 = pf.z_p0
        @z1 = pf.h + 1.0
        @z_p1 = pf.z_p1
        @len = pf.plate_l
        @wid = pf.plate_w
      end

      # 角の丸い長方形の、phi 方向の半径
      def outline(phi)
        s = Math.sin(phi) / @wid
        s = s * s * s * s
        c = Math.cos(phi) / @len
        c = c * c * c * c
        r = 1.0 / Math.sqrt(Math.sqrt(s + c))
        k = (Haniwa.wrap(phi).abs - HALF_PI) / 0.3
        r * (1.0 - 0.07 * Math.exp(-k * k))
      end

      def delta(phi, z, base)
        d = outline(phi) - base
        return d if z >= @z_p1
        # 張り出す向きごとに、板の下面を 45 度弱の斜面にする
        d -= (@z_p1 - z) / 1.1
        d > 0.0 ? d : 0.0
      end
    end

    # 首飾り (玉の連なり)。正面で少し下がる
    class Beads
      attr_reader :z0, :z1

      def initialize(zb, dip, ext, height, rref)
        @zb = zb
        @dip = dip
        @ext = ext
        @hb = height
        @rref = rref
        @n = (TWO_PI * rref / (2.1 * ext)).floor
        @n = 6 if @n < 6
        @step = TWO_PI / @n
        @z0 = zb - dip - ext
        @z1 = zb + dip + ext
      end

      def delta(phi, z, base)
        pc = (phi / @step).round * @step
        u = Haniwa.wrap(phi - pc) * @rref
        v = z - (@zb - @dip * Math.cos(pc))
        d = Math.sqrt(u * u + v * v)
        return 0.0 if d >= @ext
        @hb * Haniwa.smoothstep(1.0 - d / @ext)
      end
    end

    # 水平の帯。高さが正なら突帯・腰帯、負なら溝 (甲冑の段)
    class Band
      attr_reader :z0, :z1

      def initialize(zc, width, height, ramp)
        @zc = zc
        @half = width / 2.0
        @hh = height
        @ramp = ramp
        @z0 = zc - @half - ramp
        @z1 = zc + @half + ramp
      end

      def delta(phi, z, base)
        v = (z - @zc).abs
        @hh * Haniwa.clamp((@half + @ramp - v) / @ramp, 0.0, 1.0)
      end
    end

    # 縦の溝 (甲冑の正面の合わせ目)
    class Seam
      attr_reader :z0, :z1

      def initialize(phi0, z0, z1, width, depth, ramp, rref)
        @phi0 = phi0
        @z0 = z0
        @z1 = z1
        @half = width / 2.0
        @depth = depth
        @ramp = ramp
        @rref = rref
      end

      def delta(phi, z, base)
        u = (Haniwa.wrap(phi - @phi0) * @rref).abs
        -@depth * Haniwa.clamp((@half + @ramp - u) / @ramp, 0.0, 1.0)
      end
    end

    # たすき (斜めの帯)。体を斜めに一周する
    class Tasuki
      attr_reader :z0, :z1

      def initialize(zm, amp, width, height, ramp)
        @zm = zm
        @amp = amp
        @half = width / 2.0
        @hh = height
        @ramp = ramp
        @z0 = zm - amp - @half - ramp
        @z1 = zm + amp + @half + ramp
      end

      def delta(phi, z, base)
        v = (z - (@zm + @amp * Math.sin(phi))).abs
        @hh * Haniwa.clamp((@half + @ramp - v) / @ramp, 0.0, 1.0)
      end
    end
  end
end
