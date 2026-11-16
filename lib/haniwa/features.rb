module Haniwa
  # 半径マップ r(phi, z) に足す「くぼみ」と「盛り上がり」。
  # どれも z0..z1 (影響する高さの範囲) と delta(phi, z) を持つ。
  # phi は正面を 0 とした角度、u は表面に沿った横方向の長さ(mm)、v は縦方向の長さ(mm)。
  module Features
    # 目・口のくぼみ。形は符号付き距離 (内側が負) で決める
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

      def delta(phi, z)
        u = Haniwa.wrap(phi - @phi0) * @rref
        return 0.0 if u > @uext || u < -@uext
        t = (@ramp * 0.5 - sdf(u, z - @zc)) / @ramp
        return 0.0 if t <= 0.0
        -@depth * Haniwa.smoothstep(t)
      end

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

    # 鼻。下側を 45 度の斜面にして、サポートなしで出せる形にする
    class Nose
      attr_reader :z0, :z1

      def initialize(z_tip, height, rref)
        @zt = z_tip
        @hn = height
        @rref = rref
        @below = 1.05 * height
        @above = 2.4 * height
        @wh = 0.75 * height + 0.4
        @z0 = z_tip - @below
        @z1 = z_tip + @above
      end

      def delta(phi, z)
        u = Haniwa.wrap(phi) * @rref
        return 0.0 if u > @wh || u < -@wh
        v = z - @zt
        hv = v < 0.0 ? @hn * (1.0 + v / @below) : @hn * (1.0 - v / @above)
        d = hv - u.abs * (@hn / @wh)
        d > 0.0 ? d : 0.0
      end
    end

    # みずら (耳の横の髪の輪)。中央を少しへこませて輪に見せる
    class Lobe
      attr_reader :z0, :z1

      def initialize(phi0, zc, au, bu, bl, height, rref)
        @phi0 = phi0
        @zc = zc
        @au = au
        @bu = bu
        @bl = bl
        @hm = height
        @rref = rref
        @z0 = zc - bl
        @z1 = zc + bu
      end

      def delta(phi, z)
        u = Haniwa.wrap(phi - @phi0) * @rref
        return 0.0 if u > @au || u < -@au
        v = z - @zc
        bv = v < 0.0 ? @bl : @bu
        k = Math.sqrt((u / @au) * (u / @au) + (v / bv) * (v / bv))
        return 0.0 if k >= 1.0
        @hm * Haniwa.smoothstep(1.0 - k) * (1.0 - 0.35 * Haniwa.smoothstep(1.0 - k / 0.45))
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

      def delta(phi, z)
        pc = (phi / @step).round * @step
        u = Haniwa.wrap(phi - pc) * @rref
        v = z - (@zb - @dip * Math.cos(pc))
        d = Math.sqrt(u * u + v * v)
        return 0.0 if d >= @ext
        @hb * Haniwa.smoothstep(1.0 - d / @ext)
      end
    end

    # 水平の帯。高さが正なら突帯・腰帯、負なら溝 (甲冑風の横線)
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

      def delta(phi, z)
        v = (z - @zc).abs
        @hh * Haniwa.clamp((@half + @ramp - v) / @ramp, 0.0, 1.0)
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

      def delta(phi, z)
        v = (z - (@zm + @amp * Math.sin(phi))).abs
        @hh * Haniwa.clamp((@half + @ramp - v) / @ramp, 0.0, 1.0)
      end
    end
  end
end
