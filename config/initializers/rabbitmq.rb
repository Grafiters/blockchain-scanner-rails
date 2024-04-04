require 'bunny'
require 'yaml'

RABBITMQ_CONNECTION = Bunny.new(
  host: ENV.fetch("RABBITMQ_HOST"),
  port: ENV.fetch("RABBITMQ_PORT"),
  user: ENV.fetch("RABBITMQ_USERNAME"),
  pass: ENV.fetch("RABBITMQ_PASSWORD")
)

RABBITMQ_CONNECTION.start

channels_file = Rails.root.join('config', 'rabbitmq_channel.yml')
channels_config = YAML.load_file(channels_file)

channels_config['exchanges'].each do |exchange_config|
  exchange_name = exchange_config['name']
  exchange_type = exchange_config['type'].to_sym
  exchange_durable = exchange_config['durable']
  exchange_auto_delete = exchange_config['auto_delete']

  channel = RABBITMQ_CONNECTION.create_channel
  exchange = channel.exchange(exchange_name, type: exchange_type, durable: exchange_durable, auto_delete: exchange_auto_delete)
end

channels_config['queues'].each do |queue_config|
    Rails.logger.info queue_config
    queue_name = queue_config['name']
    queue_durable = queue_config['durable']
    queue_auto_delete = queue_config['auto_delete']
  
    channel = RABBITMQ_CONNECTION.create_channel
    queue = channel.queue(queue_name, durable: queue_durable, auto_delete: queue_auto_delete)
  
    queue_config['bindings'].each do |binding_config|
      exchange_name = binding_config['exchange']
      routing_key = binding_config['routing_key']
  
      exchange = channel.exchange(exchange_name)
      queue.bind(exchange, routing_key: routing_key)
    end
end