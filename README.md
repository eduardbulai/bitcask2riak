Bitcask to Riak
===============
This project is meant to take Bitcask folders and recursively insert data from the files into a Riak server or cluster. It uses Sidekiq with Unique Jobs Middleware to insert the data async in Riak.

Installing
==========
* Clone this repository, cd into the folder and run bundle install to fetch the required gems.
* Please don't forget to adjust the config file (config/config.yaml) according to your environment.
* Afterwards just run rackup in the folder and the app should be up and running.
* Open your browser and point it to http://127.0.0.1:1337/ (according to your config file), auth using the credentials defined in the config file and add the absolute path of your Bitcask folder (not the ring folder but the actual Bitcask path).
* Start some sidekiq workers (I highly recommend spawning separate workers for the 2 queues that are handling the migration: 'delegators' and 'heavy'). Eg: 
```
sidekiq -r ./bitcask2riak.rb -q delegators -c 5 # I usually spawn < 10 'delegators' workers otherwise my I/O is ridiculous. These are the workers responsible for reading the Bitcask files and enqueuing (bucket,key,value) jobs
```
```
sidekiq -r ./bitcask2riak.rb -q heavy -c 100 # I usually spawn 500 'heavy' workers but this depends on your hardware and network configuration
```
* Watch the magic happen in the sidekiq web UI (http://127.0.0.1:1337/sidekiq)

Use cases
=========
Using this I managed to move all the data from a Riak 0.7 Bitcask folder (~150 mil keys) to a Riak 1.4.2 cluster in under a week.
You are free to share your own experience and use case(s).

TODO
====
* Add support for compressed Bitcask data
* Your feature request here :)
	
Authors
=======
Eduard Bulai <eduard.bulai@gmail.com>
Teofil Cojocariu <teo@cojo.eu>