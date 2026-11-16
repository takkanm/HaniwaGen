require "rake/testtask"

ROOT = __dir__
SOURCES = File.readlines(File.join(ROOT, "sources.txt"), chomp: true)
              .reject { |line| line.empty? || line.start_with?("#") }
APP_RB = "public/app.rb"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = "test/*_test.rb"
  t.warning = false
end

desc "Ruby のソースを 1 本に連結して public/app.rb を作る"
task :build do
  body = SOURCES.map { |path| "# ---- #{path}\n" + File.read(File.join(ROOT, path)) }.join("\n")
  File.write(File.join(ROOT, APP_RB), body)
  puts "#{APP_RB}: #{SOURCES.size} files, #{body.bytesize} bytes"
end

desc "ビルドして http://localhost:8765 で配信する"
task serve: :build do
  require "webrick"
  server = WEBrick::HTTPServer.new(Port: (ENV["PORT"] || 8765).to_i, DocumentRoot: File.join(ROOT, "public"))
  trap("INT") { server.shutdown }
  server.start
end

desc "各プリセットの STL を tmp/stl に書き出す"
task :stl do
  require_relative "lib/haniwa"
  dir = File.join(ROOT, "tmp", "stl")
  mkdir_p dir
  Haniwa::Params::PRESETS.each_key do |name|
    params = Haniwa::Params.preset(name)
    mesh = Haniwa.build(params, "export")
    path = File.join(dir, "#{name}.stl")
    File.binwrite(path, Haniwa::STL.chunks(mesh, "HaniwaGen #{name}").join)
    puts "#{path}: #{mesh.triangle_count} triangles, #{mesh.shells.size} shells"
  end
end

task default: :test

desc "書き出した STL を trimesh で検査する (PYTHON で python を指定できる)"
task "stl:check" => :stl do
  sh ENV.fetch("PYTHON", "python3"), "script/check_stl.py", *Dir[File.join("tmp", "stl", "*.stl")].sort
end
