require "sinatra"
require "sinatra/cookies"
require "sinatra/reloader" if development?
require "pry" if development?
require "redis"
require "jwt"

# TODO: Handle CSRF.
# TODO: Don't log tokens.
before do
  pass if request.path_info == "/login"
  pass if request.path_info == "/styles.css"

  if current_user_id.nil?
    redirect("/login")
  end
end

helpers do
  def redis
    @_redis ||= Redis.new(host: ENV["REDIS_HOST"])
  end

  def current_user_email
    @_current_user_email ||= redis.hget("user:#{current_user_id}", :email)
  end

  def current_user_id
    token = cookies[:token]
    logger.info({ token: token }.to_json)

    unless token.nil?
      decoded_token = JWT.decode(token, ENV["SECRET"], true, { algorithm: "HS256" })
      logger.info({ decodedToken: decoded_token }.to_json)
      uid = decoded_token[0]["uid"]
      user_id = uid if redis.exists("user:#{uid}")
    end

    logger.info({ currentUserId: user_id }.to_json)
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
  current_card_ids = redis.smembers("user:#{current_user_id}:current-cards")

  @cards = card_ids.map do |id|
    card = redis.hgetall("card:#{id}")
    left, middle, right = card["front"].split("*")
    { id: id, left: left, middle: middle, right: right, back: card["back"], current: current_card_ids.include?(id) }
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

get "/cards/:id/edit" do
  unless redis.zrank("user:#{current_user_id}:cards", params[:id])
    halt "Card not found"
  end

  card = redis.hgetall("card:#{params[:id]}")
  @card = { id: params[:id], front: card["front"], back: card["back"] }

  erb :edit
end

patch "/cards/:id" do
  unless redis.zrank("user:#{current_user_id}:cards", params[:id])
    halt "Card not found"
  end

  redis.hmset("card:#{params[:id]}", "front", params[:front], "back", params[:back])
  redirect to("/cards/#{params[:id]}")
end

post "/current-cards" do
  unless redis.zrank("user:#{current_user_id}:cards", params[:id])
    halt "Card not found"
  end

  redis.sadd("user:#{current_user_id}:current-cards", params[:id])
  redirect to("/cards")
end

delete "/current-cards/:id" do
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

get "/login" do
  redirect to("/") if !current_user_id.nil?
  erb :login
end

post "/login" do
  user_id = redis.hget("users", params[:email])

  if !user_id.nil?
    token = JWT.encode({ uid: user_id }, ENV["SECRET"], "HS256")
    logger.info({ token: token }.to_json)
  else
    logger.info({ error: "emailDoesNotExist", email: params[:email] }.to_json)
  end

  redirect to("/")
end

delete "/logout" do
  cookies.delete(:token)
  redirect to("/")
end
