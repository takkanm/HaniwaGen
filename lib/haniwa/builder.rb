module Haniwa
  # 設定からメッシュを組み立てる入口
  module Builder
    # [円周の分割数, 高さ方向の分割数, 腕の円の分割数]
    # draft は操作中の粗い表示、preview は手を止めたあとの表示、export は STL 用。
    # 円周の分割数は、ハケ目の本数 (32 か 64) で割り切れる数にする。
    QUALITY = {
      "draft" => [128, 130, 8],
      "preview" => [192, 220, 12],
      "export" => [256, 380, 24]
    }

    def self.body_radius(params)
      params["h"] * (0.13 + 0.10 * params["g"] / 100.0)
    end

    def self.profile(params)
      Profile.new(params["h"], body_radius(params), params["body"], params["head"])
    end

    def self.build(input, quality = "preview")
      params = Params.normalize(input)
      q = QUALITY[quality] || QUALITY["preview"]
      pf = profile(params)
      mesh = Mesh.new
      hake_amp = params["hake"] == 1 ? Haniwa.max2(0.15, 0.003 * pf.h) : 0.0
      # 筋の間隔が 1mm を下回らない本数にする
      hake_n = TWO_PI * pf.r / 64.0 >= 1.0 ? 64 : 32
      Body.build(mesh, pf, features(params, pf), q[0], pf.h / q[1], hake_amp, hake_n)
      Arms.build(mesh, pf, params["arms"], q[2])
      mesh
    end

    def self.scale(v)
      0.6 + 0.8 * v / 100.0
    end

    # 目・口・透かし孔の深さ。実物の切り抜きに見えるよう深くするが、半径の 4 割までにとどめる
    def self.hole_depth(pf, radius)
      Haniwa.min2(Haniwa.max2(2.5, 0.04 * pf.h), 0.4 * radius)
    end

    def self.features(params, pf)
      list = []
      h = pf.h
      face(list, params, pf)
      hair(list, params, pf)

      # 円筒の台: 突帯 (タガ) と透かし孔
      band_h = Haniwa.max2(0.9, 0.014 * h)
      taga_w = Haniwa.max2(1.6, 0.022 * h)
      taga = [[], [0.5], [0.33, 0.66], [0.25, 0.5, 0.75]][params["taga"]]
      taga.each { |t| list << Features::Band.new(pf.z_base * t, taga_w, band_h, band_h * 1.1) }
      if params["ana"] == 1
        zc = pf.z_base * [0.5, 0.75, 0.5, 0.625][params["taga"]]
        gap = pf.z_base * [0.5, 0.25, 0.165, 0.125][params["taga"]]
        rad = Haniwa.max2(1.0, Haniwa.min2(0.04 * h, gap - taga_w * 0.5 - band_h * 1.1 - 0.4))
        [0.0, PI].each do |phi|
          list << Features::Indent.new("ellipse", phi, zc, rad, rad, pf.r_base, hole_depth(pf, pf.r_base), 0.35)
        end
      end

      # 装飾
      thin = Haniwa.max2(0.8, 0.011 * h)
      list << Features::Band.new(pf.z_waist, 0.045 * h, thin, thin * 1.1) if params["belt"] == 1
      list << Features::Tasuki.new(pf.z_sh * 0.78, pf.z_sh * 0.16, 0.04 * h, thin, thin * 1.1) if params["tasuki"] == 1
      if params["armor"] == 1
        groove = Haniwa.max2(0.8, 0.01 * h)
        width = Haniwa.max2(1.0, 0.012 * h)
        torso = pf.z_sh - pf.z_waist
        [0.36, 0.72].each { |t| list << Features::Band.new(pf.z_waist + torso * t, width, -groove, 0.6) }
        list << Features::Seam.new(0.0, pf.z_waist, pf.z_sh, width, groove, 0.6, pf.r)
      end
      if params["neck"] == 1
        ext = Haniwa.max2(1.6, 0.022 * h)
        dip = 0.02 * h
        list << Features::Beads.new(pf.z_sh - 0.035 * h - dip, dip, ext, ext * 0.6, pf.r)
      end
      list
    end

    def self.face(list, params, pf)
      rh = pf.r_head
      h = pf.h
      depth = hole_depth(pf, rh)
      ramp = 0.35

      # 目
      k = scale(params["es"])
      a = Haniwa.max2(1.0, 0.27 * rh * k)
      zc = pf.face_z(0.60 + (params["ey"] - 50) / 50.0 * 0.12)
      gap = 0.42 + (params["eg"] - 50) / 50.0 * 0.14
      eye_top = zc
      [gap, -gap].each do |phi|
        eye = params["eye"]
        if eye == "round"
          indent = Features::Indent.new("ellipse", phi, zc, 0.62 * a, 0.62 * a, rh, depth, ramp)
        elsif eye == "slit"
          indent = Features::Indent.new("slit", phi, zc, a, Haniwa.max2(0.6, 0.16 * a), rh, depth, ramp)
        elsif eye == "smile"
          indent = Features::Indent.new("arc", phi, zc, a, Haniwa.max2(0.6, 0.15 * a), rh, depth, ramp)
        else
          indent = Features::Indent.new("almond", phi, zc, a, Haniwa.max2(0.6, 0.5 * a), rh, depth, ramp)
        end
        eye_top = indent.z1
        list << indent
      end

      # 口
      k = scale(params["ms"])
      zm = pf.face_z(0.20 + (params["my"] - 50) / 50.0 * 0.08)
      mouth = params["mouth"]
      if mouth == "oval"
        a2 = Haniwa.max2(1.2, 0.30 * rh * k)
        list << Features::Indent.new("ellipse", 0.0, zm, a2, Haniwa.max2(0.6, 0.4 * a2), rh, depth, ramp)
      elsif mouth == "open"
        a2 = Haniwa.max2(1.2, 0.30 * rh * k)
        list << Features::Indent.new("ellipse", 0.0, zm, a2, 0.75 * a2, rh, depth, ramp)
      elsif mouth == "frown"
        a2 = Haniwa.max2(1.5, 0.32 * rh * k)
        list << Features::Indent.new("arc", 0.0, zm, a2, Haniwa.max2(0.6, 0.14 * a2), rh, depth, ramp)
      else
        a2 = Haniwa.max2(0.8, 0.16 * rh * k)
        list << Features::Indent.new("ellipse", 0.0, zm, a2, a2, rh, depth, ramp)
      end

      # 眉のひさし (冑をかぶっているときは、冑のふちが眉になる)
      brow_h = Haniwa.max2(0.5, 0.008 * h)
      brow_z = eye_top + 0.012 * h
      helmet = params["head"] == "helmet"
      list << Features::Brow.new(brow_z, gap + a / rh - 0.05, 0.3, 0.006 * h, brow_h) unless helmet

      # 鼻: 眉間 (冑のときはふち) から下へ伸びる稜線
      nose = params["nose"]
      if nose != "none"
        hn = h * (nose == "high" ? 0.05 : 0.03)
        z_tip = pf.face_z(0.40) - 0.5 * hn
        top = helmet ? pf.z_b0 : brow_z
        list << Features::Nose.new(z_tip, hn, rh, top - z_tip)
      end

      # 耳 (冑・みずらでは隠れる)
      head = params["head"]
      if head != "helmet" && head != "mizura"
        [1.45, -1.45].each do |phi|
          list << Features::Ear.new(phi, pf.face_z(0.5), 0.022 * h, 0.014 * h, 0.014 * h, rh)
        end
      end
    end

    def self.hair(list, params, pf)
      head = params["head"]
      h = pf.h
      if head == "mizura"
        [HALF_PI, -HALF_PI].each do |phi|
          list << Features::Mizura.new(phi, pf.z_sh, pf.face_z(0.62) + 0.03 * h, pf.r, pf.r_head + 0.05 * h, 0.045 * h, pf.r_head, h)
        end
      elsif head == "helmet"
        list << Features::Keel.new(pf, 0.04 * h, 0.2)
        list << Features::Shikoro.new(pf, 0.95)
        # 鉢を横に区切る板の継ぎ目
        groove = Haniwa.max2(0.5, 0.006 * h)
        [0.3, 0.62].each do |t|
          list << Features::Band.new(pf.z_b1 + (h - pf.z_b1) * t, Haniwa.max2(0.8, 0.008 * h), -groove, 0.5)
        end
      elsif head == "shimada"
        list << Features::Shimada.new(pf)
      end
    end
  end

  def self.build(params, quality = "preview")
    Builder.build(params, quality)
  end
end
