class WalletService
  attr_reader :wallet, :adapter

  def initialize(wallet)
    @wallet = wallet[:address]
    @blockchain = wallet[:blockchain]
    @blockchain_currency = wallet[:blockchain_currency]
    @secret = wallet[:secret]
    @adapter = Peatio::Wallet.registry[wallet[:blockchain].client.to_sym].new(wallet[:blockchain_currency].to_blockchain_api_settings)
  end

  def create_address!(uid, pa_details)
    blockchain_currency = BlockchainCurrency.find_by(currency_code: @wallet.currencies.map(&:id),
                                                     blockchain_key: @wallet.blockchain_key)

    @adapter.configure(wallet:   @wallet.to_wallet_api_settings,
                       currency: blockchain_currency.to_blockchain_api_settings)

    @adapter.create_address!(uid: uid, pa_details: pa_details)
  end

  def build_withdrawal!(withdrawal)
    blockchain_currency = BlockchainCurrency.find_by(currency: withdrawal.currency,
                                                     blockchain_key: @wallet.blockchain_key)
    @adapter.configure(wallet:   @wallet.to_wallet_api_settings,
                       currency: blockchain_currency.to_blockchain_api_settings)
    transaction = Peatio::Transaction.new(to_address: withdrawal.rid,
                                          amount:     withdrawal.amount,
                                          currency_code: withdrawal.currency_code,
                                          options: { tid: withdrawal.tid })
    transaction = @adapter.create_transaction!(transaction)
    save_transaction(transaction.as_json.merge(from_address: @wallet.address), withdrawal) if transaction.present?
    transaction
  end

  def spread_deposit(deposit)
    blockchain_currency = BlockchainCurrency.find_by(currency_code: deposit.currency_code,
                                                     blockchain_key: @blockchain_currency[:blockchain_key])
    @adapter.configure(wallet: {
      address: @wallet,
      secret: @secret
    },
      currency: blockchain_currency.to_blockchain_api_settings
    )

    # destination_wallets =
    #   Wallet.active.withdraw.ordered
    #     .joins(:currencies).where(currencies: { id: deposit.currency_code }, blockchain_key: @wallet.blockchain_key)
    #     .map do |w|
    #     # NOTE: Consider min_collection_amount is defined per wallet.
    #     #       For now min_collection_amount is currency config.
    #     { address:                 w.address,
    #       min_collection_amount:   blockchain_currency.min_collection_amount
    #     }
    #   end
    destination_wallets = [{
      address: @wallet,
      min_collection_amount: blockchain_currency.min_collection_amount,
      skip_deposit_collection: false,
      plain_settings: {}
    }]
    raise StandardError, "destination wallets don't exist" if destination_wallets.blank?

    spread_between_wallets(deposit, destination_wallets)
  end

  def load_balance_user!(address)
    record = Array.new

    address.each do |deposit|
      payment_address = PaymentAddress.find_by(id: deposit.id)
      blockchain_currencies = BlockchainCurrency.where('parent_id IS NULL').find_by(blockchain_key: payment_address.blockchain_key)

      @adapter.configure(wallet: payment_address.to_wallet_api_settings,
                          currency: blockchain_currencies.to_blockchain_api_settings)

      balance = @adapter.load_balance!

      if balance.present?
        balance_result = {
          address: deposit.address,
          balance: balance
        }

        record.push(balance_result)
      end
    end

    record
  end

  # TODO: We don't need deposit_spread anymore.
  def collect_deposit!(deposit, deposit_spread)
    configs = {
      wallet: {
        address: @wallet,
        secret: @secret,
        server: @blockchain.server_encrypted,
        uri: @blockchain.server_encrypted
      },
      currency: @blockchain_currency.to_blockchain_api_settings(withdrawal_gas_speed=false)
    }

    @adapter.configure(configs)

    deposit_spread.map do |transaction|
	# Rails.logger.warn "---------------------"
	# Rails.logger.warn transaction.inspect
      # In #spread_deposit valid transactions saved with pending state
      if transaction.status.pending?
        transaction = @adapter.create_transaction!(transaction, subtract_fee: true)
      end
      transaction
    end
  end

  # TODO: We don't need deposit_spread anymore.
  def collect_payer_fee!(payment_address)
    blockchain_currency = BlockchainCurrency.where('parent_id IS NULL').find_by(blockchain_key: @wallet.blockchain_key)

    config = {
      wallet:   @wallet.to_wallet_api_settings,
      currency: blockchain_currency.to_blockchain_api_settings
    }

    @adapter.configure(wallet:   @wallet.to_wallet_api_settings,
                       currency: blockchain_currency.to_blockchain_api)
    
    pa = PaymentAddress.find_by(address: payment_address[:address])

    fee_wallet = Wallet.active.fee.find_by(blockchain_key: pa.blockchain_key)
  #   # NOTE: Deposit wallet configuration is tricky because wallet URI
  #   #       is saved on Wallet model but wallet address and secret
  #   #       are saved in PaymentAddress.
    @adapter.configure(
      wallet: @wallet.to_wallet_api_settings
                     .merge(pa.details.symbolize_keys)
                     .merge(address: pa.address)
                     .tap { |s| s.merge!(secret: pa.secret) if pa.secret.present? }
                     .compact
    )

    collect_fee = Peatio::Transaction.new(to_address: fee_wallet.address,
                                          amount: payment_address[:balance])

    if payment_address[:balance] >= 0
      transaction = @adapter.create_transaction!(collect_fee, subtract_fee: true)
      return transaction
    end
    transaction
  end


  # TODO: We don't need deposit_spread anymore.
  def deposit_collection_fees!(deposit, deposit_spread)
    blockchain_currency = @blockchain_currency
    configs = {
      wallet: {
        address: @wallet,
        secret: @secret,
        server: @blockchain.server_encrypted,
        uri: @blockchain.server_encrypted
      },
      currency: blockchain_currency.to_blockchain_api_settings(withdrawal_gas_speed=false)
    }

    if blockchain_currency.parent_id?
      configs.merge!(parent_currency: blockchain_currency.parent.to_blockchain_api_settings)
    end

    @adapter.configure(configs)
    amount = deposit.aasm_state == 'fee_processing' && blockchain_currency.dig(:options, :erc20_contract_address) ? deposit.amount - 0.01 : deposit.amount
    deposit_transaction = Peatio::Transaction.new(hash:         deposit.txid,
                                                  txout:        deposit.txout,
                                                  to_address:   deposit.address,
                                                  block_number: deposit.block_number,
                                                  amount:       amount)

    transactions = @adapter.prepare_deposit_collection!(deposit_transaction,
                                                        # In #spread_deposit valid transactions saved with pending state
                                                        deposit_spread.select { |t| t.status.pending? },
                                                        blockchain_currency.to_blockchain_api_settings)

    if transactions.present?
      updated_spread = deposit.spread.map do |s|
        deposit_options = s.fetch(:options, {}).symbolize_keys
        transaction_options = transactions.first.options.presence || {}
        general_options = deposit_options.merge(transaction_options)

        s.merge(options: general_options)
      end

      deposit.update(spread: updated_spread)

      # transactions.each { |t| save_transaction(t.as_json.merge(from_address: @wallet.address), deposit) }
    end
    transactions
  end

  def refund!(refund)
    blockchain_currency = BlockchainCurrency.find_by(currency: refund.deposit.currency,
                                                     blockchain_key: @wallet.blockchain_key)
    @adapter.configure(wallet:   @wallet.to_wallet_api_settings,
                       currency: blockchain_currency.to_blockchain_api_settings)

    pa = PaymentAddress.find_by(wallet_id: @wallet.id, member: refund.deposit.member, address: refund.deposit.address)
    # NOTE: Deposit wallet configuration is tricky because wallet URI
    #       is saved on Wallet model but wallet address and secret
    #       are saved in PaymentAddress.
    @adapter.configure(
      wallet: @wallet.to_wallet_api_settings
                     .merge(pa.details.symbolize_keys)
                     .merge(address: pa.address)
                     .tap { |s| s.merge!(secret: pa.secret) if pa.secret.present? }
                     .compact
    )

    refund_transaction = Peatio::Transaction.new(to_address: refund.address,
                                                 amount: refund.deposit.amount,
                                                 currency_code: refund.deposit.currency_code)
    @adapter.create_transaction!(refund_transaction, subtract_fee: true)
  end

  def load_balance!(currency)
    blockchain_currency = BlockchainCurrency.find_by(currency: currency,
                                                     blockchain_key: @wallet.blockchain_key)
    @adapter.configure(wallet:   @wallet.to_wallet_api_settings,
                       currency: blockchain_currency.to_blockchain_api_settings)
    @adapter.load_balance!
  rescue Peatio::Wallet::Error => e
    report_exception(e)
    BlockchainService.new(wallet.blockchain).load_balance!(@wallet.address, currency.id)
  end

  def register_webhooks!(url)
    @adapter.register_webhooks!(url)
  end

  def fetch_transfer!(id)
    @adapter.fetch_transfer!(id)
  end

  def trigger_webhook_event(event)
    # If there are erc20 currencies system should configure parent currency here
    blockchain_currency = BlockchainCurrency.find_by(currency_code: @wallet.currencies.map(&:id),
                                                     blockchain_key: @wallet.blockchain_key,
                                                     parent_id: nil)
    @adapter.configure(wallet:   @wallet.to_wallet_api_settings,
                       currency: blockchain_currency.to_blockchain_api_settings)

    @adapter.trigger_webhook_event(event)
  end

  def skip_deposit_collection?
    @adapter.features[:skip_deposit_collection]
  end

  private

  # @return [Array<Peatio::Transaction>] result of spread in form of
  # transactions array with amount and to_address defined.
  def spread_between_wallets(deposit, destination_wallets)
    original_amount = deposit.amount
    if original_amount < destination_wallets.pluck(:min_collection_amount).min
      return []
    end

    left_amount = original_amount

    spread = destination_wallets.map do |dw|
      transaction_params = { to_address:  dw[:address],
                             amount: deposit.amount.to_d,
                             currency_id: deposit.currency_code,
                             options:     dw[:plain_settings]
                           }.compact

      transaction = Peatio::Transaction.new(transaction_params)

      # Tx will not be collected to this destination wallet
      transaction.status = :skipped if dw[:skip_deposit_collection]
      transaction
    rescue => e
      # If have exception skip wallet.
      report_exception(e)
    end
  end

  # Record blockchain transactions in DB
  def save_transaction(transaction, reference)
    transaction['txid'] = transaction.delete('hash')
    Rails.logger.warn "================================== Save Transaction"
    Rails.logger.warn transaction.as_json
    Transaction.create!(transaction.merge(reference: reference))
  end
end
