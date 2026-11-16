# 現在の設定を 1 か所で持ち、変わったら登録先に知らせる。
# 画面全体を描き直すと遅いので、各コンポーネントはここを見て自分だけを更新する。
class ParamStore
  attr_reader :params

  def initialize(params)
    @params = params
    @listeners = []
  end

  def subscribe(&block)
    @listeners << block
  end

  def code
    Haniwa::Params.encode(@params)
  end

  def set(key, value)
    replace(@params.merge({ key => value }))
  end

  def replace(params)
    params = Haniwa::Params.normalize(params)
    return if Haniwa::Params.encode(params) == code
    @params = params
    @listeners.each { |listener| listener.call(params) }
  end
end
