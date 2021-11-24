class LineBotController < ApplicationController
  protect_from_forgery except: [:callback]

  def callback
    # メッセージボディを取得
    body = request.body.read
    # 署名の検証
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      return head :bad_request
    end
    # bodyのevents以下を配列で受け取る
    events = client.parse_events_from(body)
    events.each do |event|
      # メッセージイベント（ユーザーがメッセージを送信したイベント）か判定
      case event
      when Line::Bot::Event::Message
        # eventのtypeキーがtextか判定（typeメソッド）
        case event.type
        when Line::Bot::Event::MessageType::Text
          message = search_and_create_message(event.message['text'])
          # 応答トークンを元にリプライを送信
          client.reply_message(event['replyToken'], message)
        end
      end
    end
    head :ok
  end

  private

  # Line::Bot::Clientクラスをインスタンス化
  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def search_and_create_message(keyword)
    # HTTPClientクラスをインスタンス化
    http_client = HTTPClient.new
    url = 'https://app.rakuten.co.jp/services/api/Travel/KeywordHotelSearch/20170426'
    query = {
      'keyword' => keyword,
      'applicationId' => ENV['RAKUTEN_APPID'],
      'hits' => 5,
      'responseType' => 'small',
      'formatVersion' => 2
    }
    # get(リクエストURL, パラメーターハッシュ)でAPIを叩く
    response = http_client.get(url, query)
    # 文字列からハッシュに変換
    response = JSON.parse(response.body)

    if response.key?('error')
      text = "条件に該当する宿泊施設がみつかりません"
    else
      text = ""
      response['hotels'].each do |hotel|
        text <<
          hotel[0]['hotelBasicInfo']['hotelName'] + "\n" +
          hotel[0]['hotelBasicInfo']['hotelInformationUrl'] + "\n" +
          "\n"
      end
    end

    message = {
      type: 'text',
      text: text
    }
  end
end
