module Haniwa
  # 腕。本体とは別の閉じたソリッドで、両端か根元を本体にめり込ませる。
  # サポートなしで印刷できるよう、本体の外に出る部分は水平から 50 度以上の傾きにする。
  module Arms
    SLOPE = 1.19 # tan(50度)。横に 1 進む間に縦へ進む量
    COS50 = 0.6428
    SIN50 = 0.7660

    def self.radius(profile)
      Haniwa.max2(0.24 * profile.r, 2.5)
    end

    # style: "none" | "both" | "one" | "hips" | "chest"
    def self.build(mesh, profile, style, nseg)
      return mesh if style == "none"
      if style == "both"
        raised(mesh, profile, 1.0, nseg)
        raised(mesh, profile, -1.0, nseg)
      elsif style == "one"
        raised(mesh, profile, 1.0, nseg)
        on_hip(mesh, profile, -1.0, nseg)
      elsif style == "hips"
        on_hip(mesh, profile, 1.0, nseg)
        on_hip(mesh, profile, -1.0, nseg)
      elsif style == "chest"
        on_chest(mesh, profile, 1.0, nseg)
        on_chest(mesh, profile, -1.0, nseg)
      end
      mesh
    end

    # 上げた腕: 肩の中から斜め上へ出て、まっすぐ上に伸びる
    def self.raised(mesh, pf, side, nseg)
      ra = radius(pf)
      r = pf.r
      x0 = r - 1.8 * ra
      z0 = pf.z_sh - 3.3 * ra
      x1 = r + 1.7 * ra
      z1 = z0 + (x1 - x0) * SLOPE
      len = Haniwa.min2(0.16 * pf.h, 0.97 * pf.h - ra - z1)
      len = 0.5 * ra if len < 0.5 * ra
      pts = Tube.chaikin([[side * x0, 0.0, z0], [side * x1, 0.0, z1], [side * x1, 0.0, z1 + len]], 3)
      radii = []
      i = 0
      while i < pts.size
        radii << ra
        i += 1
      end
      # 先端を丸める
      tip = pts[pts.size - 1]
      j = 1
      while j <= 3
        a = HALF_PI * j / 4.0
        pts << [tip[0], tip[1], tip[2] + 0.9 * ra * Math.sin(a)]
        radii << ra * Math.cos(a)
        j += 1
      end
      Tube.sweep(mesh, side > 0 ? "arm_r" : "arm_l", pts, radii, nseg, [tip[0], tip[1], tip[2] + 0.9 * ra])
    end

    # 腰に当てた腕: 腰から斜め上に出て肘で折れ、肩に入る
    def self.on_hip(mesh, pf, side, nseg)
      ra = radius(pf)
      r = pf.r
      xin = r - 1.8 * ra
      xout = r + 1.2 * ra
      dz = (xout - xin) * SLOPE
      z_top = pf.z_sh - 0.8 * ra
      pts = Tube.chaikin([[side * xin, 0.0, z_top - 2.0 * dz], [side * xout, 0.0, z_top - dz], [side * xin, 0.0, z_top]], 3)
      radii = []
      i = 0
      while i < pts.size
        radii << ra
        i += 1
      end
      Tube.sweep(mesh, side > 0 ? "arm_r" : "arm_l", pts, radii, nseg)
    end

    # 胸の前で合わせた腕: 肩から体の表面に沿って正面へ下りる
    def self.on_chest(mesh, pf, side, nseg)
      ra = radius(pf)
      r = pf.r
      rho = r + 0.2 * ra
      rin = r - 1.6 * ra
      phi_a = 1.1 # 63度
      phi_b = 0.10
      z_top = pf.z_sh - 1.2 * ra
      drop = rho * (phi_a - phi_b) * SLOPE
      pts = [polar(side, 1.3, rin, z_top + 0.3 * ra)]
      n = 8
      i = 0
      while i <= n
        t = i.to_f / n
        pts << polar(side, Haniwa.lerp(phi_a, phi_b, t), rho, z_top - drop * t)
        i += 1
      end
      pts << polar(side, 0.03, rin, z_top - drop - 0.3 * ra)
      pts = Tube.chaikin(pts, 1)
      radii = []
      i = 0
      while i < pts.size
        radii << ra
        i += 1
      end
      Tube.sweep(mesh, side > 0 ? "arm_r" : "arm_l", pts, radii, nseg)
    end

    def self.polar(side, phi, rad, z)
      [side * rad * Math.sin(phi), -rad * Math.cos(phi), z]
    end
  end
end
