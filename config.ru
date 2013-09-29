#\ -p 65480

require './bitcask2riak'
require 'sidekiq'
require 'sinatra'
require 'rack'
require 'sidekiq/web'

use Rack::Auth::Basic, "Protected Area" do |username, password|
  username == 'eladmino' && password == 'noestposible'
end

run Rack::URLMap.new(
  '/' => Bitcask2Riak.new, 
  '/sidekiq' => Sidekiq::Web.new)
