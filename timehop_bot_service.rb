require 'dotenv/load'
require 'telegram_bot'
require_relative './flickr_indio'

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
bot = TelegramBot.new(token: @bot_token)

puts "TimeHop Service starting"

channel = TelegramBot::Channel.new(id: @telegram_channel_id)
message = TelegramBot::OutMessage.new(chat: channel)

# fetch sets on the same day as today
date = Date.today
photos = fi.timehop(date)

puts "#{photos.size} events to report!"

if photos.any?
  # send set info and pics
  msg_text = "~~~ INDIOS TIMEHOP ~~~\nThere were #{photos.size} events on #{date.strftime('%B %-d')}:\n"
  photos.each do |photo|
    msg_text += "#{photo['title']}: #{photo['set_url']}\n"
  end

  # send message
  puts msg_text
  message.text = msg_text
  message.send_with(bot)
end
