class RabbitmqService
    def initialize(payload)
      @routing_key = payload[:routing_key]
      @exchange_name = payload[:exchange_name]
    end
  
    def handling_publish(record)
        channel_start
  
        exchange = channel.exchange(@exchange_name, type: 'topic', durable: true)
        exchange.publish(record, routing_key: @routing_key)
    end
  
    def handling_publish_event(scope, user, event, payload)
      routing_key = [scope, user, event].join('.')
      serialized_data = JSON.dump(payload)
      channel.exchange('nusa.events.ranger', type: 'topic').publish(serialized_data, routing_key: routing_key)
    end
  
    private
  
    def channel_start
      @channel = Bunny.new(
          host: ENV.fetch("RABBITMQ_HOST"),
          port: ENV.fetch("RABBITMQ_PORT"),
          user: ENV.fetch("RABBITMQ_USERNAME"),
          pass: ENV.fetch("RABBITMQ_PASSWORD")
      ).start
    end
  
    def channel
        @channel.create_channel
    end

    def find_exchange(exchanges)
      exchanges.each do |exchange_config|
        exchange_name = exchange_config['exchange']
  
        return exchange_name if exchange_config['routing_key'] == @routing_key
      end
      nil
    end
  end