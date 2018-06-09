require "sinatra"
require "redis"

get "/" do
  redis = Redis.new(host: ENV["REDIS_HOST"])
  card_ids = redis.smembers(:cards)

  @cards = card_ids.map do |id|
    redis.hgetall("card:#{id}").merge("id" => id)
  end

  erb :index
end
