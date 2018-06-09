FROM ruby
WORKDIR /app
ADD . /app
RUN gem install sinatra
RUN gem install redis
EXPOSE 80
CMD ["ruby", "cards.rb"]
