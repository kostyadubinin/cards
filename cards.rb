require "sinatra"
require "sinatra/cookies"
require "sinatra/reloader" if development?
require "pry" if development?
require "redis"
require "jwt"

# TODO: Handle CSRF.

before do
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
  card_ids = redis.smembers("user:#{current_user_id}:cards")

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
  redis.sadd("user:#{current_user_id}:cards", id)
  redirect "/"
end

delete "/cards/:id" do
  redis = Redis.new(host: ENV["REDIS_HOST"])
  redis.del("card:#{params[:id]}")
  redis.srem("user:#{current_user_id}:cards", params[:id])
  # TODO: Use `redirect to('/bar')`.
  redirect "/"
end
