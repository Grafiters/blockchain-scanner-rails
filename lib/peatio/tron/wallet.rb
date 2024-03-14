module Tron
  class Wallet < Peatio::Wallet::Abstract

    DEFAULT_ETH_FEE = { gas_limit: 2000000, gas_price: 1 }.freeze
    DEFAULT_ERC20_FEE = { gas_limit: 8000000, gas_price: 1 }.freeze
    DEFAULT_FEATURES = { skip_deposit_collection: false }.freeze
    GAS_PRICE_THRESHOLDS = { standard: 1, safelow: 0.9, fast: 1.1 }.freeze


    def initialize(custom_features = {})
      @features = DEFAULT_FEATURES.merge(custom_features).slice(*SUPPORTED_FEATURES)
      @settings = {}
    end

    def configure(settings = {})
      # Clean client state during configure.
      @client = nil

      @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))

      @wallet = @settings.fetch(:wallet) do
        raise Peatio::Wallet::MissingSettingError, :wallet
      end.slice(:uri, :address, :secret)

      @currency = @settings.fetch(:currency) do
        raise Peatio::Wallet::MissingSettingError, :currency
      end.slice(:id, :base_factor, :options)
    end

    def create_address!(options = {})
      response = client.rest_api(:get, '/create-account', {})
      { address: response['address'], secret: response['privateKey'], details: response }
    rescue Tron::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    def create_transaction!(transaction, options = {})
      if @currency.dig(:options, :erc20_contract_address).present?
        contract_address = @currency.dig(:options, :erc20_contract_address)
        if(contract_address.length > 15)
          create_erc20_transaction!(transaction)
        else
          create_erc10_transaction!(transaction,contract_address)
        end
      else
        create_eth_transaction!(transaction, options)
      end
    rescue Tron::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    def prepare_deposit_collection!(transaction, deposit_spread, deposit_currency)
      # # Don't prepare for deposit_collection in case of eth deposit.
      return [] if deposit_currency.dig(:options, :erc20_contract_address).blank?
      return [] if deposit_spread.blank?
      options = DEFAULT_ERC20_FEE.merge(deposit_currency.fetch(:options).slice(:gas_limit))
      fees = convert_from_base_unit(options.fetch(:gas_limit).to_i * options.fetch(:gas_price).to_i)
      toaddress = transaction.to_address
      Rails.logger.warn options.as_json
      Rails.logger.warn fees * deposit_spread.size
      transaction.amount = fees * deposit_spread.size
      [create_eth_transaction!(transaction)]
    rescue Tron::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    def load_balance!
      if @currency.dig(:options, :erc20_contract_address).present?
        contract_address = @currency.dig(:options, :erc20_contract_address)
        if(contract_address.length > 15)
          load_erc20_balance(@wallet.fetch(:address))
        else
          load_erc10_balance(@wallet.fetch(:address),contract_address)
        end
      else
        response = client.rest_api(:post, '/get-tron-balance', {address:@wallet.fetch(:address) })
        convert_from_base_unit(response['balance'])
      end
    rescue Tron::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    private

    def load_erc20_balance(address)
      response = client.rest_api(:post, '/get-trc20-balance', {contractAddress: contract_address, address:address })
      convert_from_base_unit(response['balance'])
    end

    def load_erc10_balance(address,contract_address)
      response = client.rest_api(:post, '/get-trc10-balance', {contractAddress: contract_address, address:address })
      convert_from_base_unit(response['balance'])
    end

    def create_eth_transaction!(transaction, options = {})
      currency_options = @currency.fetch(:options).slice(:gas_limit, :gas_price)
      options.merge!(DEFAULT_ETH_FEE, currency_options)
      amount = convert_to_base_unit(transaction.amount)
      if transaction.options.present?
        options[:gas_price] = transaction.options[:gas_price]
      end

      # Subtract fees from initial deposit amount in case of deposit collection
      amount -= options.fetch(:gas_limit).to_i * options.fetch(:gas_price).to_i if options.dig(:subtract_fee)

      params = {
        to: normalize_address(transaction.to_address),
        amount: amount,
        privKey: @wallet.fetch(:secret)
      }

      response = client.rest_api(:post, '/send-transaction', params)
      hash = response.fetch('hash')
      unless hash
        raise Tron::Client::Error, \
              "Withdrawal from #{@wallet.fetch(:address)} to #{transaction.to_address} failed."
      end
      Rails.logger.warn hash.as_json
      # Make sure that we return currency_code
      transaction.currency_id= 'trx' if transaction.currency_id.blank?
      transaction.amount = amount
      transaction.hash = hash
      transaction.options = options
      transaction
    end

    def create_erc10_transaction!(transaction, contract_address,options = {})
      currency_options = @currency.fetch(:options).slice(:gas_limit, :gas_price)
      options.merge!(DEFAULT_ETH_FEE, currency_options)
      amount = convert_to_base_unit(transaction.amount)

      if transaction.options.present?
        options[:gas_price] = transaction.options[:gas_price]
      end
      # Subtract fees from initial deposit amount in case of deposit collection
      amount -= options.fetch(:gas_limit).to_i * options.fetch(:gas_price).to_i if options.dig(:subtract_fee)


      params = {
        to: normalize_address(transaction.to_address),
        amount: amount,
        privKey: @wallet.fetch(:secret),
        tokenID: contract_address,
      }
      response = client.rest_api(:post, '/send-trc20', params)
      hash = response.fetch('hash')
      unless hash
        raise Tron::Client::Error, \
              "Withdrawal from #{@wallet.fetch(:address)} to #{transaction.to_address} failed."
      end
      # Make sure that we return currency_code
      transaction.currency_id = 'trx' if transaction.currency_id.blank?
      transaction.amount = amount
      transaction.hash = hash
      transaction.options = options
      transaction
    end

    def create_erc20_transaction!(transaction, options = {})
      currency_options = @currency.fetch(:options).slice(:gas_limit, :gas_price, :erc20_contract_address)
      options.merge!(DEFAULT_ERC20_FEE, currency_options)

      amount = convert_to_base_unit(transaction.amount)
      amount_str = amount.to_s

      params = {
      	contractAddress: options.fetch(:erc20_contract_address),
      	from: @wallet.fetch(:address),
      	to: transaction.to_address,
      	amount: amount_str,
      	privKey: @wallet.fetch(:secret),
        feelimit: options.fetch(:gas_limit).to_i
      }
      response = client.rest_api(:post, '/send-trc20', params)

      hash = response.fetch('hash')
      unless hash
        raise Tron::WalletClient::Error, \
              "Withdrawal from #{@wallet.fetch(:address)} to #{transaction.to_address} failed."
      end
      transaction.hash = hash
      transaction.options = options
      transaction
    end

    def normalize_address(address)
      address
    end

    def normalize_txid(txid)
      txid.downcase
    end

    def contract_address
      normalize_address(@currency.dig(:options, :erc20_contract_address))
    end

    def valid_txid?(txid)
      txid.to_s.match?(/\A0x[A-F0-9]{64}\z/i)
    end

    def abi_encode(method, *args)
      '0x' + args.each_with_object(Digest::SHA3.hexdigest(method, 256)[0...8]) do |arg, data|
        data.concat(arg.gsub(/\A0x/, '').rjust(64, '0'))
      end
    end

    def convert_from_base_unit(value)
      value.to_d / 10**@currency.fetch(:base_factor)
    end

    def convert_to_base_unit(value)
      x = value.to_d * 10**@currency.fetch(:base_factor)
      unless (x % 1).zero?
        raise Peatio::WalletClient::Error,
            "Failed to convert value to base (smallest) unit because it exceeds the maximum precision: " \
            "#{value.to_d} - #{x.to_d} must be equal to zero."
      end
      x.to_i
    end


    def client
      uri = @wallet.fetch(:uri) { raise Peatio::Wallet::MissingSettingError, :uri }
      @client ||= Client.new(uri, idle_timeout: 1)
    end
  end
end
