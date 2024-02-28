# frozen_string_literal: true

module Workers
  module Daemons
    class Deposit < Base
      self.sleep_time = 60

      def process
        # Process deposits with `processing` state each minute
        ::Deposit.processing.each do |deposit|
          Rails.logger.info { "Starting processing coin deposit with id: #{deposit.id}." }

          wallet = Wallet.where('trx_address = ? OR eth_address = ? ', deposit.address, deposit.address).first
          unless wallet
            Rails.logger.warn { "Can't find active deposit wallet for currency with code: #{deposit.currency_code}."}
            next
          end

          # Check if adapter has prepare_deposit_collection! implementation
          begin
            # Process fee collection for tokens
            collect_fee(deposit)
            # Will be processed after fee collection
            next if deposit.fee_processing?
          rescue StandardError => e
            Rails.logger.error { "Failed to collect deposit fee #{deposit.id}. See exception details below." }
            report_exception(e)
            deposit.err! e

            raise e if is_db_connection_error?(e)

            next
          end

          process_deposit(deposit)
        end

        # Process deposits in `fee_processing` state that already transfered fees for collection
        ::Deposit.fee_processing.where('updated_at < ?', 1.minute.ago).each do |deposit|
          Rails.logger.info { "Starting processing token deposit with id: #{deposit.id}." }

          process_deposit(deposit)
        end
      end

      def process_deposit(deposit)
        if deposit.spread.blank?
          deposit.spread_between_wallets!
          Rails.logger.warn { "The deposit was spreaded in the next way: #{deposit.spread}"}
        end

        fee_wallet = Setting.find_by(name: 'PAYER_FEE_WALLET_KEY')
        unless fee_wallet
          Rails.logger.warn { "Can't find active fee wallet for currency with code: #{deposit.currency_code}."}
          return
        end

        wallet = Wallet.where('trx_address = ? OR eth_address = ? ', deposit.address, deposit.address).first
        priv_key_decrypt = EncryptionService.new({payload: wallet[:encrypted_private_key]}).decrypt
        priv_key = deposit.blockchain_key.include?('tron') ? priv_key_decrypt[:privateKey].sub(/^0x/, "") : priv_key_decrypt[:privateKey]

        service = WalletService.new({address: hot_wallet(deposit).value, secret: priv_key, blockchain: deposit.blockchain, blockchain_currency: deposit.blockchain_currencies})

        transactions = service.collect_deposit!(deposit, deposit.spread_to_transactions)

        if transactions.present?
          # Save txids in deposit spread.
          deposit.update!(spread: transactions.map(&:as_json))

          Rails.logger.warn { "The API accepted deposit collection and assigned transaction ID: #{transactions.map(&:as_json)}." }

          deposit.dispatch!
        else
          deposit.skip!
          "Skipped deposit with txid: #{deposit.txid} with amount: #{deposit.amount}"\
          " to #{deposit.address}"
        end
      rescue StandardError => e
        Rails.logger.error { "Failed to collect deposit #{deposit.id}. See exception details below." }
        report_exception(e)

        raise e if is_db_connection_error?(e)
      end

      def collect_fee(deposit)
        if deposit.spread.blank?
          deposit.spread_between_wallets!
          Rails.logger.warn { "The deposit was spread in the next way: #{deposit.spread}"}
        end

        fee_wallet = Setting.find_by(name: 'PAYER_FEE_WALLET_KEY')
        unless fee_wallet
          Rails.logger.warn { "Can't find active fee wallet for currency with code: #{deposit.currency_code}."}
          return
        end

        priv_key_decrypt = EncryptionService.new(payload: fee_wallet[:value]).decrypt
        priv_key = deposit.blockchain_key.include?('tron') ? priv_key_decrypt[:privateKey].sub(/^0x/, "") : priv_key_decrypt[:privateKey]

        transactions = WalletService.new({address: deposit.address, secret: priv_key, blockchain: deposit.blockchain, blockchain_currency: deposit.blockchain_currencies}).deposit_collection_fees!(deposit, deposit.spread_to_transactions)
        deposit.fee_process! if transactions.present?
        Rails.logger.warn { "The API accepted token deposit collection fee and assigned transaction ID: #{transactions.map(&:as_json)}." }
      end

      def hot_wallet(deposit)
        deposit_cat = deposit.blockchain_key.include?('tron') ? 'HOT_WALLET_TRX_ADDRESS' : 'HOT_WALLET_ETH_ADDRESS'
        Setting.find_by(name: 'PAYER_FEE_WALLET_KEY')
      end
    end
  end
end
