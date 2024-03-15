# frozen_string_literal: true

require 'bunny'
require 'ostruct'
require "uri"
require "net/http"
require "json"

class BlockService
  Error = Class.new(StandardError)

  class VerificationError < Error; end

  def initialize(events)
    @exchanges = events

    Kernel.at_exit { unlisten }
  end

  def call
    listen
  end

  private

  def listen
    unlisten

    @bunny_session = Bunny::Session.new(rabbitmq_credentials).tap do |session|
      session.start
      Kernel.at_exit { session.stop }
    end

    Rails.logger.warn @bunny_session.inspect

    @bunny_channel = @bunny_session.channel
    # Delete old queue if some exists
    queue = @bunny_channel.queue(ENV.fetch('BLOCK_ROUTEING_KEY'), auto_delete: false, durable: true)
    queue.bind(@exchanges)

    exchange_name = @exchanges
    exchange = @bunny_channel.direct(exchange_name)

    queue.bind(exchange, routing_key: ENV.fetch('BLOCK_ROUTEING_KEY'))

    queue.subscribe(manual_ack: true, block: true, &method(:handle_message))
  end

  def unlisten
    if @bunny_session || @bunny_channel
      Rails.logger.info { 'No longer listening for events.' }
    end

    @bunny_channel&.work_pool&.kill
    @bunny_session&.stop
  ensure
    @bunny_channel = nil
    @bunny_session = nil
  end

  def rabbitmq_credentials
    {
        host: ENV.fetch("RABBITMQ_HOST"),
        port: ENV.fetch("RABBITMQ_PORT"),
        user: ENV.fetch("RABBITMQ_USERNAME"),
        pass: ENV.fetch("RABBITMQ_PASSWORD")
    }
  end

  def handle_message(delivery_info, _metadata, payload)
    Rails.logger.warn { "Start handling a message" }
    Rails.logger.warn { "\nPayload: \n #{payload} \n\n Metadata: \n #{_metadata} \n\n Delivery info: \n #{delivery_info} \n" }
    
    payload_data = JSON.parse(payload, symbolize_names: true)
    # data = JSON.parse(payload_data)
    if payload_data[:type] == 'tx_id'
      blockNumber = process_tx_id(payload_data)

      payload_data[:block] = blockNumber

      process_block(payload_data)
    elsif payload_data[:type] == 'block'
      process_block(payload_data)
    else
      Rails.logger.error { 'Payload tidak sesuai' }
    end

    @bunny_channel.ack(delivery_info.delivery_tag)
  end

  def process_block(payload)
    blockchain = ::Blockchain.find_by(key: payload[:blockchain_key])
    bc_service = BlockchainService.new(blockchain)

    bc_service.process_block(payload[:block])
  end

  def process_tx_id(payload)
    is_tron = payload[:blockchain_key].include?('tron')

    if is_tron
      server = ENV.fetch("RPC_TRON_NETWORK")
      url_str = "#{server}/wallet/gettransactioninfobyid"
      Rails.logger.warn url_str
      url = URI(url_str)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(url)
      request["accept"] = 'application/json'
      request["content-type"] = 'application/json'
      request.body = JSON.generate({ "value" => payload[:tx_id] })
      response = http.request(request)
      # Response Example: {"id": "6845cd84618fea8c1d8b675233121c89b08a46a2a7202a66ece5e170136a2e6b","fee": 5797020,"blockNumber": 45153601,"blockTimeStamp": 1710393204000,"contractResult": ["0000000000000000000000000000000000000000000000000000000000000001"],"contract_address": "412a79bd6dd35adf9d7618c31b3dfedd83f798a217","receipt": {"energy_fee": 5452020,"energy_usage_total": 12981,"net_fee": 345000,"result": "SUCCESS"},"log": [{"address": "2a79bd6dd35adf9d7618c31b3dfedd83f798a217","topics": ["ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0000000000000000000000005a162f9cb5d70f1ce5df8674ea829d9776ffb8b4","000000000000000000000000d021166e52b66868bf8236877e1bdfdb40a919a0"],"data": "0000000000000000000000000000000000000000000000004563918244f40000"}],"packingFee": 5797020}
      response_body_json = response.read_body
      response_body = JSON.parse(response_body_json)
      block_number = response_body["blockNumber"]
      Rails.logger.warn "Block Number: #{block_number}"
      return block_number
    end

    tx = payload[:tx_id]
    blockchain = ::Blockchain.find_by(key: payload[:blockchain_key])
    
    network = payload[:blockchain_key].split('-')
    server = ENV.fetch("RPC_#{network[0].upcase}_NETWORK")

    getReceipt = Ethereum::Client.new(server).json_rpc(:eth_getTransactionReceipt, [tx])

    Rails.logger.warn getReceipt.fetch('blockNumber')
    return getReceipt.fetch('blockNumber').to_i(16)
  end

  def db_connection_error?(exception)
    exception.is_a?(Mysql2::Error::ConnectionError) || exception.cause.is_a?(Mysql2::Error)
  end

  class << self
    def call(*args)
      new(*args).call
    end
  end
end