require 'rubygems'
require 'redis'

class FlickrDb
  REDIS_PREFIX = 'indiosbot'
  PIC_PREFIX = "#{REDIS_PREFIX}_pic_"
  # we have a 'left' set so we don't have to do set diffs all the time
  ALL_PICS = "#{REDIS_PREFIX}_all_pics"
  LEFT_PICS = "#{REDIS_PREFIX}_left_pics"
  SEEN_PICS = "#{REDIS_PREFIX}_seen_pics"

  def initialize(opts={debug: false})
    @redis = Redis.new
    @debug = opts[:debug]
  end

  def cache!(pics)
    puts "Caching #{pics.size} photos" if @debug
    # store pic details as JSON
    pics.each do |pic|
      @redis.set "#{PIC_PREFIX}#{pic['id']}", pic.to_json
    end

    # make sure we have an updated list of all the pics
    ids = pics.map{|p| p['id']}
    @redis.sadd ALL_PICS, ids # set ignores dups

    # calculate which pics we have left as of right now
    @redis.del LEFT_PICS
    @redis.sadd LEFT_PICS, @redis.sdiff(ALL_PICS, SEEN_PICS)
  end

  # should we do this explicitly?
  # def seen(id)
  #   @redis.sadd(SEEN_PICS, id)
  # end

  # return unseen pic id and mark it as seen
  def unseen
    pic_id = @redis.spop(LEFT_PICS)
    @redis.sadd SEEN_PICS, pic_id
    puts "Returning unseen pic #{pic_id}. All pics: #{@redis.scard(ALL_PICS)}, left: #{@redis.scard(LEFT_PICS)}, seen: #{@redis.scard(SEEN_PICS)}" if @debug
    JSON.parse(@redis.get "#{PIC_PREFIX}#{pic_id}")
  end

  # return random pic id
  def random
    pic_id = @redis.srandmember(ALL_PICS)
    puts "Returning random pic #{pic_id}. All pics: #{@redis.scard(ALL_PICS)}, left: #{@redis.scard(LEFT_PICS)}, seen: #{@redis.scard(SEEN_PICS)}" if @debug
    JSON.parse(@redis.get "#{PIC_PREFIX}#{pic_id}")
  end

  def stats
    { all: @redis.scard(ALL_PICS), left: @redis.scard(LEFT_PICS), seen: @redis.scard(SEEN_PICS) }
  end
end
