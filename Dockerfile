FROM ruby
WORKDIR /app
ADD . /app
RUN gem install sinatra redis jwt sinatra-contrib
EXPOSE 80
CMD ["ruby", "cards.rb"]
