threads 8,250
preload_app!

bind 'unix:///tmp/puma.socket'
# bind 'tcp://0.0.0.0:9080'

before_fork do
  ActiveRecord::Base.connection_pool.disconnect!
end

on_worker_boot do
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.establish_connection
  end
end