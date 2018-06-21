require "sinatra"
require "sinatra/cookies"
require "sinatra/reloader" if development?
require "pry" if development?
require "redis"
require "jwt"

# TODO: Handle CSRF.
before do
  # cookies[:token] = JWT.encode({ uid: 1 }, ENV["SECRET"], "HS256")

  if current_user_id.nil?
    halt "Access denied, please login."
  end
end

helpers do
  def redis
    @_redis ||= Redis.new(host: ENV["REDIS_HOST"])
  end

  def current_user_id
    token = cookies[:token]
    logger.info("token=#{token.inspect}")

    unless token.nil?
      decoded_token = JWT.decode(token, ENV["SECRET"], true, { algorithm: "HS256" })
      logger.info("decodedToken=#{decoded_token.inspect}")
      uid = decoded_token[0]["uid"]
      user_id = uid if redis.exists("user:#{uid}")
    end

    logger.info("currentUserId=#{user_id.inspect}")
    user_id
  end
end

get "/styles.css" do
  scss :styles
end

get "/cards/new" do
  erb :new
end

get "/" do
  card_ids = redis.smembers("user:#{current_user_id}:current-cards")

  @cards = card_ids.map do |id|
    card = redis.hgetall("card:#{id}")
    left, middle, right = card["front"].split("*")
    { id: id, left: left, middle: middle, right: right, back: card["back"] }
  end

  erb :index
end

get "/cards" do
  card_ids = redis.zrevrange("user:#{current_user_id}:cards", 0, -1)

  @cards = card_ids.map do |id|
    card = redis.hgetall("card:#{id}")
    left, middle, right = card["front"].split("*")
    { id: id, left: left, middle: middle, right: right, back: card["back"] }
  end

  erb :cards
end

get "/cards/random" do
  id = redis.srandmember("user:#{current_user_id}:current-cards")
  redirect to("/cards/#{id}")
end

get "/cards/:id" do
  unless redis.zrank("user:#{current_user_id}:cards", params[:id])
    halt "Card not found"
  end

  card = redis.hgetall("card:#{params[:id]}")
  left, middle, right = card["front"].split("*")
  @card = { id: params[:id], left: left, middle: middle, right: right, back: card["back"] }

  erb :card
end

post "/current-cards" do
  unless redis.zrank("user:#{current_user_id}:cards", params[:id])
    halt "Card not found"
  end

  redis.sadd("user:#{current_user_id}:current-cards", params[:id])
  redirect to("/cards")
end

delete "/current-cards" do
  unless redis.zrank("user:#{current_user_id}:cards", params[:id])
    halt "Card not found"
  end

  redis.srem("user:#{current_user_id}:current-cards", params[:id])
  redirect to("/")
end

post "/cards" do
  id = redis.incr(:next_card_id)
  redis.hmset("card:#{id}", "front", params[:front], "back", params[:back])
  redis.zadd("user:#{current_user_id}:cards", Time.now.to_i, id)
  redirect to("/cards")
end

delete "/cards/:id" do
  unless redis.zrank("user:#{current_user_id}:cards", params[:id])
    halt "Card not found"
  end

  redis.zrem("user:#{current_user_id}:cards", params[:id])
  redis.srem("user:#{current_user_id}:current-cards", params[:id])
  redis.del("card:#{params[:id]}")
  redirect to("/cards")
end
