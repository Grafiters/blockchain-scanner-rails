require 'bunny'
require 'yaml'

RABBITMQ_CONNECTION = Bunny.new(
  host: ENV.fetch("RABBITMQ_HOST"),
  port: ENV.fetch("RABBITMQ_PORT"),
  user: ENV.fetch("RABBITMQ_USERNAME"),
  pass: ENV.fetch("RABBITMQ_PASSWORD")
)

RABBITMQ_CONNECTION.start

exchange_name = ENV.fetch('BLOCK_EXCHANGE_NAME')
exchange_type = 'direct'
exchange_durable = false
exchange_auto_delete = false

channel = RABBITMQ_CONNECTION.create_channel
exchange = channel.exchange(exchange_name, type: exchange_type, durable: exchange_durable, auto_delete: exchange_auto_delete)

queue_name = ENV.fetch('BLOCK_QUEUE_NAME')
queue_durable = true
queue_auto_delete = false

channel = RABBITMQ_CONNECTION.create_channel
queue = channel.queue(queue_name, durable: queue_durable, auto_delete: queue_auto_delete)

routing_key = 'blockchain.fetch_block'

exchange = channel.exchange(exchange_name)
queue.bind(exchange, routing_key: routing_key)