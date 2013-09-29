require './bitcask2riak'
require 'sidekiq'
require 'sinatra'
require 'rack'
require 'sidekiq/web'

run Rack::URLMap.new(
  '/' => Bitcask2Riak.new, 
  '/sidekiq' => Sidekiq::Web.new)