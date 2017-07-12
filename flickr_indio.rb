require 'dotenv/load'
require 'rubygems'
require 'flickraw'
require 'date'
require_relative './flickr_db'

class FlickrIndio

  attr_accessor :photosets

  def initialize
    @api_key = FlickRaw.api_key = ENV.fetch('FLICKR_API_KEY')
    FlickRaw.shared_secret = ENV.fetch('FLICKR_SHARED_SECRET')

    # 1st time auth:
    #
    # token = flickr.get_request_token
    # auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')
    #
    # puts "Open this url in your process to complete the authication process : #{auth_url}"
    # puts "Copy here the number given when you complete the process."
    # verify = gets.strip
    #
    # begin
    #   flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
    #   login = flickr.test.login
    #   puts "You are now authenticated as #{login.username} with token #{flickr.access_token} and secret #{# flickr.access_secret}"
    # rescue FlickRaw::FailedResponse => e
    #   puts "Authentication failed : #{e.msg}"
    # end

    flickr.access_token = ENV.fetch('FLICKR_ACCESS_TOKEN')
    flickr.access_secret = ENV.fetch('FLICKR_ACCESS_SECRET')

    @photosets = flickr.photosets.getList
    @flickr_db = FlickrDb.new(debug: true)
  end

  def inspect
    "FlickrIndio {api_key: #{@api_key}}"
  end

  def cache_photos!
    cache_all_photos
  end

  # returns a random photo {:title, :url} from the entire collection
  def get_random_photo
    @flickr_db.random
  end

  # returns an unseen photo {:title, :url} from the collection
  def get_unseen_photo
    @flickr_db.unseen
  end

  # returns details about events that happened on this day
  def timehop(date=Date.today)
    sets = sets_on_this_day(date)
    sets.map { |set| get_random_photo_from_set(set['id'], set['photos']) }
  end

  def tag(photo_id, tags)
    return unless tags.any?
    clean_tags = tags.map { |t| t.gsub(/#/,'') } + ['indios_bot']
    flickr.photos.addTags(photo_id: photo_id, tags: clean_tags.join(','))
  end

  def rotate(photo_id, angle)
    return unless angle && angle > 0
    flickr.photos.transform.rotate(photo_id: photo_id, degrees: angle)
  end

  def stats
    @flickr_db.stats
  end

  private

  def cache_all_photos
    @photosets.each do |set|
      pics = []
      sleep 1
      pages = (set['photos'] / 500) + 1
      puts "set #{set['id']} has #{pages} pages"
      1.upto(pages) do |page|
        puts "fetching page #{page}"
        pics += flickr.photosets.getPhotos(photoset_id: set['id'], page: page)['photo'].map{|p| get_pic_struct(set['id'], set['title'], p)}
      end
      @flickr_db.cache! pics
    end
  end

  # returns a random photo {:title, :url} from the given set
  def get_random_photo_from_set(set_id, photo_count=500)
    # randomize a photo index, so we know which page to fetch
    page = (rand(photo_count) / 500) + 1
    # fetch set photos
    resp = flickr.photosets.getPhotos(photoset_id: set_id, page: page)
    # pic one randomly
    photos = resp['photo']
    photo = photos[rand(photos.size)]
    get_pic_struct(set_id, resp['title'], photo)
  end

  def sets_on_this_day(date)
    partial_date = date.strftime('.%m.%d')
    puts partial_date
    @photosets.select{|p| p['title'].include?(partial_date) }
  end

  def get_pic_struct(set_id, set_title, photo)
    {
      'id' => photo['id'],
      'title' => set_title,
      # https://farm{farm-id}.staticflickr.com/{server-id}/{id}_{secret}.jpg
      'url' => "https://farm#{photo['farm']}.staticflickr.com/#{photo['server']}/#{photo['id']}_#{photo['secret']}_c.jpg",
      # https://www.flickr.com/photos/{user-id}/sets/{photoset-id}/
      'set_url' => "https://www.flickr.com/photos/indios/sets/#{set_id}/"
    }
  end
end
