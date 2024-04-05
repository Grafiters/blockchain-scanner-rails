# encoding: UTF-8
# frozen_string_literal: true

module Workers
  module AMQP
    class DepositCoinAddress < Base
      def process(payload)
        payload.symbolize_keys!

        wallet = Wallet.find_by_id(payload[:wallet_id])

        unless wallet
          Rails.logger.warn do
            'Unable to generate deposit address.'\
            "Deposit Wallet with id: #{payload[:wallet_id]} doesn't exist"
          end
          return
        end

        wallet_service = WalletService.new(wallet)

        PaymentAddress.where(wallet_id: wallet.id).each do |pa|
          next if pa.address.present?

          # Supply address ID in case of BitGo address generation if it exists.
          details = {}
          result = wallet_service.create_address!("-", details.merge(updated_at: pa.updated_at))

          if result.present?
            pa.update!(address: result[:address],
                       secret:  result[:secret],
                       details: result[:details])

            pa.trigger_address_event
          end
        end 

      # Don't re-enqueue this job in case of error.
      # The system is designed in such way that when user will
      # request list of accounts system will ask to generate address again (if it is not generated of course).
      rescue StandardError => e
        raise e if is_db_connection_error?(e)

        report_exception(e)
      end
    end
  end
end
