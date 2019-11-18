class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require "open-uri"
  require 'net/http'
  require "json"
  API_KEY = ENV['API_KEY']
  GOOGLE_API_KEY =  ENV['GOOGLE_API_KEY']
  BASE_URL = "http://api.openweathermap.org/data/2.5/weather"
  GOOGLE_URL = "https://maps.googleapis.com/maps/api/geocode/json"


  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head :bad_request
    end

    events = client.parse_events_from(body)

    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          case event.message['text'] 
          when /^こんにちは/
            message = {
              type: 'text',
              text: "おはよーう"
            }
        

          when /^おは/
            message = {
              type: 'text',
              text: "こんばんは〜〜"
            }

          when /.*名前.*/, /.*なまえ.*/
            message = {
              type: 'text',
              text: "ぼくはけいしだよ"
            }
          
          when /.*天気.*/, /.*てんき.*/
            kakko = /ー.*ー/
            if event.message['text'] =~ kakko
              location = event.message['text'].scan(kakko).to_s[3..-4]
            else
              message = {
                type: 'text',
                text: "どこの天気が知りたい？こんな風に聞いてみて！\n（例）ー東京ーの天気"
              }
              client.reply_message(event['replyToken'], message)
              return
            end
            # googlemapAPIから緯度経度取得
            uri = URI.parse("#{GOOGLE_URL}?address=#{URI.encode(location)}&sensor=false&language=ja&key=#{GOOGLE_API_KEY}")
            res = Net::HTTP.get_response(uri)
            loc_data = JSON.parse(res.body, {symbolize_names: true})
            lat = loc_data[:results][0][:geometry][:location][:lat]
            lon = loc_data[:results][0][:geometry][:location][:lng]
            # 緯度経度で天気を検索
            response = open(BASE_URL + "?units=metric&lat=#{lat}&lon=#{lon}&lang=ja&APPID=#{API_KEY}")
            data = JSON.parse(response.read, {symbolize_names: true})
            weather = data[:weather][0][:description]
            temp_min = data[:main][:temp_min].round(0)
            temp_max = data[:main][:temp_max].round(0)
            message = {
              type: 'text',
              text: "今日の#{location}の天気は「#{weather}」\n最低気温は約#{temp_min}度\n最高気温は約#{temp_max}度だよ"
            }

          
          else 
            @post = Post.all
            id = rand(@post.length)
            message = {type: "text", text: @post[id].text }
          end

          client.reply_message(event['replyToken'], message)
        end
      end
    }

    head :ok
  end
end