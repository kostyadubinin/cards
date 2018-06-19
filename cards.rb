require "sinatra"
require "sinatra/cookies"
require "sinatra/reloader" if development?
require "pry" if development?
require "redis"
require "jwt"

# TODO: Handle CSRF.
# TODO: Test cookies in production (domain, path, secure?, etc.).

before do
  # cookies[:token] = JWT.encode({ uid: 1 }, ENV["SECRET"], "HS256")

  if current_user_id.nil?
    halt "Access denied, please login."
  end
end

helpers do
  def current_user_id
    token = cookies[:token]
    logger.info("token=#{token.inspect}")

    unless token.nil?
      decoded_token = JWT.decode(token, ENV["SECRET"], true, { algorithm: "HS256" })
      logger.info("decodedToken=#{decoded_token.inspect}")
      uid = decoded_token[0]["uid"]
      redis = Redis.new(host: ENV["REDIS_HOST"])
      user_id = uid if redis.exists("user:#{uid}")
    end

    logger.info("currentUserId=#{user_id.inspect}")
    user_id
  end
end

get "/" do
  redis = Redis.new(host: ENV["REDIS_HOST"])
  card_ids = redis.smembers("user:#{current_user_id}:current-cards")

  @cards = card_ids.map do |id|
    card = redis.hgetall("card:#{id}")
    left, middle, right = card["front"].split("*")
    { id: id, left: left, middle: middle, right: right, back: card["back"] }
  end

  erb :index
end

get "/cards" do
  redis = Redis.new(host: ENV["REDIS_HOST"])
  card_ids = redis.zrevrange("user:#{current_user_id}:cards", 0, -1)

  @cards = card_ids.map do |id|
    card = redis.hgetall("card:#{id}")
    left, middle, right = card["front"].split("*")
    { id: id, left: left, middle: middle, right: right, back: card["back"] }
  end

  erb :cards
end

get "/cards/random" do
  redis = Redis.new(host: ENV["REDIS_HOST"])
  id = redis.srandmember("user:#{current_user_id}:current-cards")
  redirect "/cards/#{id}"
end

get "/cards/:id" do
  redis = Redis.new(host: ENV["REDIS_HOST"])

  unless redis.zrank("user:#{current_user_id}:cards", params[:id])
    halt "Card not found"
  end

  card = redis.hgetall("card:#{params[:id]}")
  left, middle, right = card["front"].split("*")
  @card = { id: params[:id], left: left, middle: middle, right: right, back: card["back"] }

  erb :card
end

post "/current-cards" do
  redis = Redis.new(host: ENV["REDIS_HOST"])

  unless redis.zrank("user:#{current_user_id}:cards", params[:id])
    halt "Card not found"
  end

  redis.sadd("user:#{current_user_id}:current-cards", params[:id])
  redirect "/cards"
end

delete "/current-cards" do
  redis = Redis.new(host: ENV["REDIS_HOST"])

  unless redis.zrank("user:#{current_user_id}:cards", params[:id])
    halt "Card not found"
  end

  redis.srem("user:#{current_user_id}:current-cards", params[:id])
  redirect "/"
end

post "/cards" do
  redis = Redis.new(host: ENV["REDIS_HOST"])
  id = redis.incr(:next_card_id)
  redis.hmset("card:#{id}", "front", params[:front], "back", params[:back])
  redis.zadd("user:#{current_user_id}:cards", Time.now.to_i, id)
  redirect "/cards"
end

delete "/cards/:id" do
  redis = Redis.new(host: ENV["REDIS_HOST"])

  unless redis.zrank("user:#{current_user_id}:cards", params[:id])
    halt "Card not found"
  end

  redis.zrem("user:#{current_user_id}:cards", params[:id])
  redis.srem("user:#{current_user_id}:current-cards", params[:id])
  redis.del("card:#{params[:id]}")
  # TODO: Use `redirect to('/bar')`.
  redirect "/cards"
end
