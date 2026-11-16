# CRuby 用の読み込み口。ブラウザでは sources.txt の順に連結したものを使う。
root = File.expand_path("..", __dir__)
File.readlines(File.join(root, "sources.txt"), chomp: true).each do |line|
  next if line.empty? || line.start_with?("#") || !line.start_with?("lib/")
  require File.join(root, line)
end
