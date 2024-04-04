# encoding: UTF-8
# frozen_string_literal: true

module Workers
    module AMQP
      class SchaningBlock < Base
        def process(payload)
            blockchain = Blockchain.find_by(key: payload[:blockchain_key])
            if payload[:type] == 'txid'
                proces = blockchain.blockchain_api.fetch_tx_transacton(payload[:value])
                Rails.logger.warn proces
            else
                if blockchain.client == 'tron'
                    blockchain.blockchain_api.process_multiple_block(payload[:block_number], payload[:block_number])
                else
                    blockchain.blockchain_api.process_block(payload[:block_number])
                end
            end
        rescue StandardError => e
          raise e if is_db_connection_error?(e)
  
          report_exception(e)
        end
      end
    end
  end
  