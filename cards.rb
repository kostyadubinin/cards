require "sinatra"
require "sinatra/cookies"
require "sinatra/reloader" if development?
require "redis"
require "jwt"

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

post "/cards" do
  redis = Redis.new(host: ENV["REDIS_HOST"])
  id = redis.incr(:next_card_id)
  redis.hmset("card:#{id}", "front", params[:front], "back", params[:back])
  redis.sadd("cards", id)
  redirect "/"
end

delete "/cards/:id" do
  redis = Redis.new(host: ENV["REDIS_HOST"])
  redis.del("card:#{params[:id]}")
  redis.srem("cards", params[:id])
  redirect "/"
end

get "/login" do
  erb :login
end

post "/check-your-inbox" do
  @email = params[:email]
  erb :check_your_inbox
end
