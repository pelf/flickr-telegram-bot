require 'dotenv/load'
require 'telegram_bot'
require_relative './flickr_indio'

def send_msg(msg_text)
  message = TelegramBot::OutMessage.new(chat: @channel)
  puts msg_text
  message.text = msg_text
  message.send_with(@bot)
end

if ARGV[0] == 'live'
  @mode = :live
  @telegram_channel_id = ENV.fetch('CHANNEL_ID_LIVE')
  @bot_token = ENV.fetch('BOT_TOKEN_LIVE')
else
  @mode = :test
  @telegram_channel_id = ENV.fetch('CHANNEL_ID_TEST')
  @bot_token = ENV.fetch('BOT_TOKEN_TEST')
end

fi = FlickrIndio.new
@bot = TelegramBot.new(token: @bot_token)
@channel = TelegramBot::Channel.new(id: @telegram_channel_id)

puts "TimeHop Service starting"

# fetch sets on the same day as today
date = Date.today
photos = fi.timehop(date).reverse

puts "#{photos.size} events to report!"

if photos.any?
  # send title and set info
  msg_text = "~~~ INDIOS TIMEHOP ~~~\nThere were #{photos.size} events on #{date.strftime('%B %-d')}:\n"
  photos.each do |photo|
    msg_text += " - #{photo['title']}\n"
  end
  # send title message
  send_msg msg_text

  photos.each do |photo|
    sleep 5
    send_msg "#{photo['url']}\nTag this img with: /tagid #{photo['id']} ..."
  end
end
