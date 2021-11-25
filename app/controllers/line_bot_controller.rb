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
          p "+++++++++++++"
          p message
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
      'datumType' => 1,
      'responseType' => 'small',
      'formatVersion' => 2
    }
    # get(リクエストURL, パラメーターハッシュ)でAPIを叩く
    response = http_client.get(url, query)
    # 文字列からハッシュに変換
    response = JSON.parse(response.body)

    if response.key?('error')
      {
        type: 'text',
        text: '条件に該当する宿泊施設がみつかりません'
      }
    else
      # 正常なレスポンスの時はflexを返す
      {
        type: 'flex',
        altText: '宿泊検索の結果です',
        contents: set_carousel(response['hotels'])
      }
    end
  end

  def set_carousel(hotels)
    bubbles = []
    hotels.each do |hotel|
      bubbles << set_bubble(hotel[0]['hotelBasicInfo'])
    end
    {
      type: 'carousel',
      contents: bubbles
    }
  end

  def set_bubble(hotel)
    {
      type: 'bubble',
      hero: set_hero(hotel),
      body: set_body(hotel),
      footer: set_footer(hotel)
    }
  end

  def set_hero(hotel)
    {
      type: 'image',
      url: hotel['hotelImageUrl'],
      size: 'full',
      aspectRatio: '20:13',
      aspectMode: 'cover',
      action: {
        type: 'uri',
        url: hotel['hotelInformationUrl']
      }
    }
  end

  def set_body(hotel)
    {
      type: 'box',
      layout: 'vertical',
      contents: [
        {
          type: 'text',
          text: hotel['hotelName'],
          weight: 'bold',
          size: 'md',
          wrap: true
        },
        {
          type: 'box',
          layout: 'vertical',
          margin: 'lg',
          spacing: 'sm',
          contents: [
            {
              type: 'box',
              layout: 'baseline',
              spacing: 'sm',
              contents: [
                {
                  type: 'text',
                  text: '住所',
                  color: '#aaaaaa',
                  size: 'sm',
                  flex: 1
                },
                {
                  type: 'text',
                  text: hotel['address1'] + hotel['address2'],
                  wrap: true,
                  color: '#666666',
                  size: 'sm',
                  flex: 5
                }
              ]
            },
            {
              type: 'box',
              layout: 'baseline',
              spacing: 'sm',
              contents: [
                {
                  type: 'text',
                  text: '料金',
                  color: '#aaaaaa',
                  size: 'sm',
                  flex: 1
                },
                {
                  type: 'text',
                  text: '￥' + hotel['hotelMinCharge'].to_s + '〜',
                  wrap: true,
                  color: '#666666',
                  size: 'sm',
                  flex: 5
                }
              ]
            }
          ]
        }
      ]
    }
  end

  def set_footer(hotel)
    {
      type: 'box',
      layout: 'vertical',
      spacing: 'sm',
      contents: [
        {
          type: 'button',
          style: 'link',
          height: 'sm',
          action: {
            type: 'uri',
            label: '電話する',
            uri: 'tel:' + hotel['telephoneNo']
          }
        },
        {
          type: 'button',
          style: 'link',
          height: 'sm',
          action: {
            type: 'uri',
            label: '地図を見る',
            uri: 'https://www.google.com/maps?q=' + hotel['latitude'].to_s + hotel['longitude'].to_s
          }
        },
        {
          type: 'spacer',
          size: 'sm'
        }
      ],
      flex: 0
    }
  end
end
