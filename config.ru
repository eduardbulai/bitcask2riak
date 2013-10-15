require './bitcask2riak'
require 'sidekiq'
require 'sinatra'
require 'rack'
require 'sidekiq/web'
require 'yaml'

$config = YAML.load_file('./config/config.yaml')

app = Rack::Builder.new {
  use Rack::Auth::Basic, "Protected Area" do |username, password|
    username == $config['auth']['user'] && password == $config['auth']['pass']
  end
  
  map "/" do
    run Bitcask2Riak
  end

  map "/sidekiq" do
    run Sidekiq::Web
  end
}

Rack::Handler.get('webrick').run(app.to_app, :Port => $config['server']['port'])