FROM ruby
ENV LANG C.UTF-8
WORKDIR /app
ADD . /app
RUN gem install sinatra redis jwt sinatra-contrib sass puma
EXPOSE 80
CMD ["puma"]
