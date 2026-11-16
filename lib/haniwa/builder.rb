module Haniwa
  # 設定からメッシュを組み立てる入口
  module Builder
    # [円周の分割数, 高さ方向の分割数, 腕の円の分割数]
    QUALITY = {
      "preview" => [112, 150, 12],
      "export" => [256, 380, 28]
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
      Body.build(mesh, pf, features(params, pf), q[0], pf.h / q[1])
      Arms.build(mesh, pf, params["arms"], q[2])
      mesh
    end

    def self.scale(v)
      0.6 + 0.8 * v / 100.0
    end

    def self.features(params, pf)
      list = []
      h = pf.h
      rh = pf.r_head
      depth = Haniwa.max2(1.0, 0.022 * h)
      ramp = Haniwa.max2(0.5, 0.008 * h)
      face(list, params, pf, depth, ramp)

      if params["head"] == "mizura"
        zc = pf.face_z(0.5)
        [HALF_PI, -HALF_PI].each do |phi|
          list << Features::Lobe.new(phi, zc, 0.05 * h, 0.06 * h, 0.085 * h, 0.05 * h, rh)
        end
      end

      band_h = Haniwa.max2(0.9, 0.014 * h)
      taga_w = Haniwa.max2(1.6, 0.022 * h)
      taga = [[], [0.22], [0.14, 0.32], [0.10, 0.24, 0.38]][params["taga"]]
      taga.each { |t| list << Features::Band.new(pf.z_sh * t, taga_w, band_h, band_h * 1.1) }

      thin = Haniwa.max2(0.8, 0.011 * h)
      list << Features::Band.new(pf.z_sh * 0.52, 0.045 * h, thin, thin * 1.1) if params["belt"] == 1
      list << Features::Tasuki.new(pf.z_sh * 0.70, pf.z_sh * 0.22, 0.04 * h, thin, thin * 1.1) if params["tasuki"] == 1
      if params["armor"] == 1
        groove = Haniwa.max2(0.8, 0.01 * h)
        [0.66, 0.76, 0.86].each do |t|
          list << Features::Band.new(pf.z_sh * t, Haniwa.max2(1.0, 0.012 * h), -groove, 0.6)
        end
      end
      if params["neck"] == 1
        ext = Haniwa.max2(1.6, 0.022 * h)
        dip = 0.02 * h
        list << Features::Beads.new(pf.z_sh - 0.035 * h - dip, dip, ext, ext * 0.6, pf.r)
      end
      list
    end

    def self.face(list, params, pf, depth, ramp)
      rh = pf.r_head
      # 目
      k = scale(params["es"])
      a = Haniwa.max2(1.0, 0.27 * rh * k)
      zc = pf.face_z(0.62 + (params["ey"] - 50) / 50.0 * 0.12)
      gap = 0.42 + (params["eg"] - 50) / 50.0 * 0.14
      [gap, -gap].each do |phi|
        eye = params["eye"]
        if eye == "round"
          list << Features::Indent.new("ellipse", phi, zc, 0.62 * a, 0.62 * a, rh, depth, ramp)
        elsif eye == "slit"
          list << Features::Indent.new("slit", phi, zc, a, Haniwa.max2(0.6, 0.16 * a), rh, depth, ramp)
        elsif eye == "smile"
          list << Features::Indent.new("arc", phi, zc, a, Haniwa.max2(0.6, 0.15 * a), rh, depth, ramp)
        else
          list << Features::Indent.new("almond", phi, zc, a, Haniwa.max2(0.6, 0.5 * a), rh, depth, ramp)
        end
      end

      # 口
      k = scale(params["ms"])
      zm = pf.face_z(0.20 + (params["my"] - 50) / 50.0 * 0.08)
      mouth = params["mouth"]
      if mouth == "oval"
        a = Haniwa.max2(1.2, 0.30 * rh * k)
        list << Features::Indent.new("ellipse", 0.0, zm, a, Haniwa.max2(0.6, 0.4 * a), rh, depth, ramp)
      elsif mouth == "open"
        a = Haniwa.max2(1.2, 0.30 * rh * k)
        list << Features::Indent.new("ellipse", 0.0, zm, a, 0.75 * a, rh, depth, ramp)
      elsif mouth == "frown"
        a = Haniwa.max2(1.5, 0.32 * rh * k)
        list << Features::Indent.new("arc", 0.0, zm, a, Haniwa.max2(0.6, 0.14 * a), rh, depth, ramp)
      else
        a = Haniwa.max2(0.8, 0.16 * rh * k)
        list << Features::Indent.new("ellipse", 0.0, zm, a, a, rh, depth, ramp)
      end

      # 鼻
      nose = params["nose"]
      if nose != "none"
        hn = pf.h * (nose == "high" ? 0.055 : 0.03)
        list << Features::Nose.new(pf.face_z(0.42) - 0.5 * hn, hn, rh)
      end
    end
  end

  def self.build(params, quality = "preview")
    Builder.build(params, quality)
  end
end
