require "sinatra"
require "sinatra/cookies"
require "sinatra/reloader" if development?
require "pry" if development?
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
  redis = Redis.new(host: ENV["REDIS_HOST"])
  @email = params[:email]

  if redis.hexists(:users, @email)
    id = redis.hget(:users, @email)
    logger.info("UserId=#{id} found")
  else
    id = redis.incr(:next_user_id)
    redis.hset(:users, @email, id)
    redis.hset("user:#{id}", :email, @email)
    logger.info("UserId=#{id} created")
  end

  # TODO: Generate a JWT token.
  # TODO: Send a link with the token.

  erb :check_your_inbox
end
