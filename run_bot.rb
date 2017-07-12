require_relative './indios_bot'

mode = (ARGV[0] == 'live') ? :live : :test
bot = IndiosBot.new(mode)

loop do
  begin
    bot.run!
  rescue
  end
end
