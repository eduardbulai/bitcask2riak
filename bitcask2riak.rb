require 'sinatra'
class Bitcask2Riak < Sinatra::Application
  require 'sinatra'
  require 'sidekiq'
  require 'sidekiq-middleware'
  require 'redis'
  require 'awesome_print'
  require 'bitcask'
  require 'bert'
  require 'riak'

  # to change the redis server just run this in the terminal
  # export REDIS_URL='redis://host:port'
  $redis = Redis.new

  Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add Sidekiq::Middleware::Server::UniqueJobs
    end
  end

  class BitcaskWorker
    include Sidekiq::Worker
    sidekiq_options :retry => 100, :queue => :delegators

    def perform(folder)
      b = Bitcask.new folder
      b.load
      sep1 = "\x01{\\\""
      sep2 = "}\x00\x00\x00"
      b.data_files.each do |data_file|
        data_file.each do |entry|
          next if entry.value == Bitcask::TOMBSTONE
          # Get Data
          key_decode = BERT.decode(entry.key)       
          bucket = key_decode[0]
          key = key_decode[1]

          value = "{\"" + entry.value[/#{sep1}(.*?)#{sep2}/m, 1] + "}"
          RiakWorker.perform_async(bucket, key, value)
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
        {:host => '192.168.37.57', :pb_port => 8087}
      ])
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
      <input type="text" name="msg">
      <input type="submit" value="Add Folder">
    </form>
    <a href="/sidekiq" target="_blank">View stats</a>'
  end

  post '/do' do
    BitcaskWorker.perform_async params[:msg]
    redirect to('/')
  end
  # End Sinatra app
end

