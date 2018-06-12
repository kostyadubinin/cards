FROM ruby
WORKDIR /app
ADD . /app
RUN gem install sinatra
RUN gem install redis
RUN gem install jwt
RUN gem install sinatra-contrib
EXPOSE 80
CMD ["ruby", "cards.rb"]
