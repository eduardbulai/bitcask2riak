require 'sinatra'
require 'sidekiq'
require 'sidekiq-middleware'
require 'redis'
require 'awesome_print'
require 'bitcask'
require 'bert'
require 'riak'
require 'yaml'

class Bitcask2Riak < Sinatra::Application

  $config = YAML.load_file('./config/config.yaml')
  # to change the redis server just run this in the terminal
  # export REDIS_URL='redis://host:port'

  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add Sidekiq::Middleware::Server::UniqueJobs
    end
    config.redis = { :url => $config['redis']['url'], :namespace => $config['redis']['namespace'] }
  end

  Sidekiq.configure_client do |config|
    config.redis = { :url => $config['redis']['url'], :namespace => $config['redis']['namespace'] }
  end

  #$redis = Redis.new({:url => $config['redis']['url'], :namespace => $config['redis']['namespace']})

  class BitcaskWorker
    include Sidekiq::Worker
    sidekiq_options :retry => 100, :queue => :delegators

    def perform(folder)
      b = Bitcask.new folder
      b.load
      sep1 = "\x01{\\\""
      sep2 = "}\x00\x00\x00"
      b.data_files.each do |data_file|
        if data_file.count > 0 
          stats = Sidekiq::Stats.new
          ap stats.enqueued
          data_file.each do |entry|
            unless stats.enqueued.to_i < 10000
              puts "Too much jobs. Sleeping for 60 seconds...\r\n"
              sleep 60
              redo  
            else
              next if entry.value == Bitcask::TOMBSTONE
              # Get Data
              key_decode = BERT.decode(entry.key)       
              bucket = key_decode[0]
              key = key_decode[1]
              value = BERT.decode(entry.value).last
              worker = RiakWorker.perform_async(bucket, key, value)
              puts "Enqueued #{worker.inspect}"
            end
          end
        end
      end
    end
  end

  class RiakWorker
    include Sidekiq::Worker
    sidekiq_options :retry => 20, :queue => :heavy
    sidekiq_options({unique: :all, expiration: 24 * 60 * 60})

    def perform(bucket, key, val)
      # Retrieve a bucket
      # Create a client interface
      client = Riak::Client.new(:nodes => [
        {:host => '192.168.37.57', :pb_port => 8087}],
        :protocol => 'pbc')
      bucket = client.bucket(bucket)  # a Riak::Bucket

      # Create a new object
      new_one = Riak::RObject.new(bucket, key)
      new_one.content_type = "application/json" # You must set the content type.
      new_one.raw_data = val
      new_one.store
    end
  end

  get '/' do
    '<h1>Bitcask to Riak Mover</h1>

    <form method="post" action="/do">
      <input type="text" name="dir">
      <input type="submit" value="Add Bitcask Folder">
    </form>
    <a href="/sidekiq" target="_blank">View stats</a>'
  end

  post '/do' do
    partitions = Dir.glob("#{params[:dir]}/**")
    partitions.each do |partition|
      BitcaskWorker.perform_async(partition)
    end
    redirect to('/')
  end
  # End Sinatra app
end

