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
    blockchain = ::Blockchain.find_by(key: payload_data[:blockchain_key])
    proces_block = nil
    if payload_data[:type] == 'txid'
        proces = blockchain.blockchain_api.fetch_tx_transacton(payload_data[:value])
      
        if !proces.nil?
          proces_block = blockchain.blockchain_api.process_block(proces['blockNumber'])
        end
    else
        if blockchain.client == 'tron'
          proces_block = blockchain.blockchain_api.process_multiple_block(payload_data[:block_number], payload_data[:block_number])
        else
          proces_block = blockchain.blockchain_api.process_block(payload_data[:block_number])
        end
    end

    Rails.logger.warn proces_block
    @bunny_channel.ack(delivery_info.delivery_tag)
  end

  def process_block(payload)
    blockchain = ::Blockchain.find_by(key: payload[:blockchain_key])
    bc_service = BlockchainService.new(blockchain)

    bc_service.process_block(payload[:block])
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