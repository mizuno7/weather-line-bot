class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
    events = client.parse_events_from(body)
    events.each { |event|
      case event
        # メッセージが送信された場合の対応（機能①）
      when Line::Bot::Event::Message
        case event.type
          # ユーザーからテキスト形式のメッセージが送られて来た場合
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          input = event.message['text']
          url  = "https://www.drk7.jp/weather/xml/13.xml"
          xml  = open( url ).read.toutf8
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'
          # 当日朝のメッセージの送信の下限値は20％としているが、明日・明後日雨が降るかどうかの下限値は30％としている
          min_per = 50
          case input
            # 「今日」or「きょう」「天気」というワードが含まれる場合
          when /.*(今日|きょう|天気|てんき|本日|ほんじつ).*/
            # info[2]：明日の天気
            per06to12 = doc.elements[xpath + 'info[1]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[1]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[1]/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "今日の天気だよね?\n今日は雨が降りそうだよ(>_<)\n降水確率はこんな感じだよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　#{per12to18}％\n　18〜24時　#{per18to24}％"
            else
              push =
                "今日の天気だよね?\n今日は雨が降らない予定だよ(^^)\n降水確率はこんな感じだよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　#{per12to18}％\n　18〜24時　#{per18to24}％"
            end
          when /.*(明日|あした|あす).*/
            # info[2]：明日の天気
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明日の天気だよね。\n明日は雨が降りそうだよ(>_<)\n今のところ降水確率はこんな感じだよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　#{per12to18}％\n　18〜24時　#{per18to24}％\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
            else
              push =
                "明日の天気？\n明日は雨が降らない予定だよ(^^)\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
            end
          when /.*(明後日|あさって).*/
            per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]l'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明後日の天気だよね。\n何かあるのかな？\n明後日は雨が降りそう…\n当日の朝に雨が降りそうだったら教えるからね！"
            else
              push =
                "明後日の天気？\n気が早いねー！何かあるのかな。\n明後日は雨は降らない予定だよ(^^)\nまた当日の朝の最新の天気予報で雨が降りそうだったら教えるからね！"
            end
          when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ|かっこいい｜イケメン|えらい|偉い).*/
            push =
              "ありがとう！！！\n優しい言葉をかけてくれるあなたはとても素敵です(^^)"
          when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
            push =
              "こんにちは。\n声をかけてくれてありがとう\n今日があなたにとっていい日になりますように(^^)"
          else
            word =
              ["こんにちは！！",
                "今日も元気かい？(^^)",
                "暇かな？(^_^)",
                "今日も一日頑張ろう！",
                "ちょっとスマホ見るのを\n止めてみよう(*^^*)",
                "さあ下ばっか向いてないで\n顔を上げよう！",
                "いつもお疲れ様！",
                "頑張っているね！",
                "今日の格言！\n自分自身を信じてみるだけでいい。\nきっと、生きる道が見えてくる。\nby ゲーテ",
                "今日の格言！\n運がいい人も運が悪い人もいない。\n運がいいと思う人と、\n運が悪いと思う人がいるだけだ。\nby 中谷彰宏",
                "今日の格言！\n夢中で日を過ごしておれば、\nいつかはわかる時が来る。\nby 坂本龍馬",
                "今日の格言！\n一生の間に一人の人間でも\n幸福にすることが出来れば\n自分の幸福なのだ\nby 川端康成",
                "今日の格言！\n最も大きな危険は勝利の瞬間にある。\nby ナポレオン",
                "今日の格言！\n速度を上げるばかりが人生ではない。\nby ガンジー",
                "今日の格言！\n世界で最も素晴らしく、\n最も美しいものは、目で見たり\n手で触れたりすることはできません。\nそれは、心で感じなければならないのです。\nby ヘレン・ケラー",
                "今日の格言！\n何かを学ぶのに、自分自身で経験する以上に良い方法はない。\nby アインシュタイン",
                "今日の格言！\n生きるとは呼吸することではない。\n行動することだ。\nby ジャン＝ジャック・ルソー",
                "今日の格言！\n朝寝は時間の出費である。\nしかも、これほど高価な出費は他にない。\nby カーネギー",
                "今日の格言！\n人の一生は、重荷を負うて\n遠き路を行くが如し。急ぐべからず。\nby 徳川家康",
                "今日の格言！\n理想を持ち、信念に生きよ。\nby 織田信長",
                "今日の格言！\nいまの僕には勢いがある\nby 松岡修造",
                "今日の格言！\n布団たたきは、やめられない。\nついつい叩きすぎちゃう。\nby 松岡修造",
                "今日の格言！\n真剣だからこそ、ぶつかる壁がある。\nby 松岡修造",
                "今日の格言！\n一日生きることは、一歩進むことでありたい。\nby 湯川秀樹",
                "今日の格言！\nペンは剣よりも強し\nby 福沢諭吉",
                "今日の格言！\nもし今日が人生最後の日だとしたら、\n今やろうとしていることは本当に\n自分のやりたいことだろうか？\nby スティーブ・ジョブズ",
                "今日の格言！\nハングリーであれ。愚か者であれ。\nStay hungry. Stay foolish.\nby スティーブ・ジョブズ"].sample
            push =
              "#{word}"
          end
          # テキスト以外（画像等）のメッセージが送られた場合
        else
          push = "文字以外はわからないよ~"
        end
        message = {
          type: 'text',
          text: push
        }
        client.reply_message(event['replyToken'], message)
        # LINEお友達追された場合（機能②）
      when Line::Bot::Event::Follow
        # 登録したユーザーのidをユーザーテーブルに格納
        line_id = event['source']['userId']
        User.create(line_id: line_id)
        # LINEお友達解除された場合（機能③）
      when Line::Bot::Event::Unfollow
        # お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end
    }
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end

