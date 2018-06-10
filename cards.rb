require "sinatra"
require "redis"

get "/" do
  redis = Redis.new(host: ENV["REDIS_HOST"])
  card_ids = redis.smembers(:cards)

  @cards = card_ids.map do |id|
    card = redis.hgetall("card:#{id}").merge("id" => id)
    left, middle, right = card["front"].split("*")
    { id: id, left: left, middle: middle, right: right, back: card["back"] }
  end

  erb :index
end
