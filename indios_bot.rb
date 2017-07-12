require 'dotenv/load'
require_relative './flickr_indio'
require 'telegram_bot'

class IndiosBot
  BOT_TOKENS = {
      test: ENV.fetch('BOT_TOKEN_TEST'),
      live: ENV.fetch('BOT_TOKEN_LIVE')
    }
  FLICKR_COOLDOWN = 10 # seconds
  TAG_COOLDOWN = 5 # seconds
  DEL_COOLDOWN_SPEEDUP = 5 # secs
  PRINT_TAG = 'to_print'
  DELETE_TAG = 'to_delete'

  def initialize(mode=:test)
    @op_mode = (mode == :live) ? :live : :test
    # initialize flickr and bot
    @flickr_indio = FlickrIndio.new
    @bot = TelegramBot.new(token: BOT_TOKENS[@op_mode])

    # store last pic sent to each channel
    @last_pics = {}
    # keep track of last sent pic timestamp to reduce spam
    @timestamps = {}
    # keep track of rotations
    @rotations = {}
  end

  def run!
    puts "Bot starting in #{@op_mode} mode."

    # do what bots do...
    @bot.get_updates(fail_silently: true) do |message|
      begin
        puts "@#{message.from.username}: #{message.text}"
        command = message.get_command_for(@bot)
        chat_id = message.chat.id

        case command
        when /\/flickr/i, /\/f$/i
          cmd_flickr(message)
        when /\/timehop/i
          # TODO return random pic from an event on this day (check timehop service)
        when /\/print/i, /\/save/i, /\/p$/i
          cmd_print(chat_id)
        when /\/delete/i, /\/del$/i, /\/d$/i
          cmd_delete(chat_id)
        when /\/tags? /i, /\/t /i
          cmd_tag_last(message, command)
        when /\/tid /i, /\/tagid /i
          cmd_tag_id(message, command)
        when /\/rotate/i, /\/r$/i, /\/r /i
          cmd_rotate(message, command)
        when /\/help/i, /\/h ?$/i
          cmd_help(message)
        when /\/stats?/i, /\/s ?$/i
          cmd_stats(message)
        else
          # shhht!
        end
      rescue => e # sometimes flickr goes berserk
        puts e
        puts e.backtrace
      end
    end
  end

  private

  # reply with random flickr image
  def cmd_flickr(message)
    chat_id = message.chat.id
    message.reply do |reply|
      if cooldown_over?(chat_id)
        reply.text = "Hold your horses! Please wait #{FLICKR_COOLDOWN}s after a /flickr or #{TAG_COOLDOWN}s after a /tag call."
      else
        photo = @flickr_indio.get_unseen_photo
        set_last_pic(chat_id, photo['id'])
        set_cooldown(chat_id, FLICKR_COOLDOWN)
        reset_rotations(chat_id)
        reply.text = "#{photo['title']}\nPhoto ID: #{photo['id']}\n#{photo['url']}"
      end
      puts "sending #{reply.text.inspect} to @#{message.from.username}"
      reply.send_with(@bot)
    end
  end

  # tag last pic as printable
  def cmd_print(chat_id)
    return unless (last_pic_id=last_pic(chat_id))
    @flickr_indio.tag(last_pic_id, [PRINT_TAG])
    puts "tagged #{last_pic_id} as to_print"
  end

  # tag last pic as deletable
  def cmd_delete(chat_id)
    return unless (last_pic_id=last_pic(chat_id))
    @flickr_indio.tag(last_pic_id, [DELETE_TAG])
    speed_up_cooldown(chat_id, DEL_COOLDOWN_SPEEDUP)
    puts "tagged #{last_pic_id} as to_delete"
  end

  # add tag(s) to last pic
  def cmd_tag_last(message, command)
    chat_id = message.chat.id
    return unless (last_pic_id=last_pic(chat_id))
    set_cooldown(chat_id, TAG_COOLDOWN)
    tags = command.split[1..-1] # /cmd tag1 tag2 ...
    tag_pic(last_pic_id, tags)
  end

  # add tag(s) to last pic
  def cmd_tag_id(message, command)
    chat_id = message.chat.id
    tags = command.split[1..-1] # /cmd <id> tag1 tag2...
    pic_id = tags.shift # first 'tag' is the pic_id
    return unless pic_id && tags.any?
    tag_pic(pic_id, tags)
  end

  # rotate last pic
  def cmd_rotate(message, command)
    chat_id = message.chat.id
    return unless (last_pic_id=last_pic(chat_id)) && !@rotations[chat_id]
    angle = get_angle_value(command.split[1])
    @flickr_indio.rotate(last_pic_id, angle)
    @rotations[chat_id] = true
    puts "rotated #{last_pic_id} with #{angle}"
  end

  def cmd_help(message)
    message.reply do |reply|
      reply.text = "~~~ LIST OF COMMANDS ~~~\n"\
        "/f[lickr]: get unseen flickr photo\n"\
        "/d[elete]: mark last photo for deletion\n"\
        "/h[elp]: duh\n"\
        "/p[rint]: mark last photo as printable\n"\
        "/r[otate] [angle=90,180,270,cw,ccw,-90]: rotate last photo (defaults to +90)\n"\
        "/s[tats]: display stats\n"\
        "/t[ag] tag1 tag2...: tag last photo\n"\
        "/t[ag]id <id> tag1 tag2...: tag previous photo by id\n"
      reply.send_with(@bot)
    end
  end

  def cmd_stats(message)
    stats = @flickr_indio.stats

    message.reply do |reply|
      reply.text = "#{((stats[:seen].to_f/stats[:all])*100).round(2)}% done, total: #{stats[:all]}, seen: #{stats[:seen]}, left: #{stats[:left]}"
      reply.send_with(@bot)
    end
  end

  # add tag(s) to pic by id
  def tag_pic(pic_id, tags)
    @flickr_indio.tag(pic_id, tags)
    puts "tagged #{pic_id} with #{tags}"
  end

  def last_pic(chat_id)
    @last_pics[chat_id]
  end

  def set_last_pic(chat_id, pid)
    @last_pics[chat_id] = pid
  end

  def speed_up_cooldown(chat_id, secs)
    return unless @timestamps[chat_id]
    @timestamps[chat_id] -= secs
  end

  def set_cooldown(chat_id, secs)
    # sets new cooldown time or keeps current one if it's further ahead in time (useful for a /t after a /f)
    @timestamps[chat_id] = [ (@timestamps[chat_id] || 0), (timestamp + secs) ].max
  end

  def cooldown_over?(chat_id)
    # no ruby 2.3 on the server, so we can't use &. for nil checks
    @timestamps[chat_id] && @timestamps[chat_id] > timestamp
  end

  def reset_rotations(chat_id)
    @rotations[chat_id] = nil
  end

  def get_angle_value(angle)
    return 90 unless angle
    case angle.strip
    when /^90/, /^cw/
      90
    when /180/
      180
    when /270/, /ccw/, /-90/
      270
    else
      0
    end
  end

  def timestamp
    Time.now.to_i
  end
end
