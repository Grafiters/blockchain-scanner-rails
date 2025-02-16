module Ether
  class Wallet < Peatio::Wallet::Abstract

    DEFAULT_ETH_FEE = { gas_limit: 21_000, gas_price: 75_000 }.freeze
    DEFAULT_ERC20_FEE = { gas_limit: 90_000, gas_price: 75_000 }.freeze
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
    rescue Ether::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    def create_transaction!(transaction, options = {})
      if @currency.dig(:options, :erc20_contract_address).present?
        create_erc20_transaction!(transaction)
      else
        # create_erc20_transaction!(transaction, options)
	       create_eth_transaction!(transaction, options)
      end
    rescue Ether::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    def prepare_deposit_collection!(transaction, deposit_spread, deposit_currency)
      # Don't prepare for deposit_collection in case of eth deposit.
      return [] if deposit_currency.dig(:options, :erc20_contract_address).blank?
      return [] if deposit_spread.blank?

      options = DEFAULT_ERC20_FEE.merge(deposit_currency.fetch(:options).slice(:gas_limit, :gas_price))

      options[:gas_price] = calculate_gas_price(options)

      # We collect fees depending on the number of spread deposit size
      # Example: if deposit spreads on three wallets need to collect eth fee for 3 transactions
      fees = convert_from_base_unit(options.fetch(:gas_limit).to_i * options.fetch(:gas_price).to_i)
      transaction.amount = fees * deposit_spread.size
      transaction.options = options

      [create_eth_transaction!(transaction)]
    rescue Ether::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    def load_balance!
      if @currency.dig(:options, :erc20_contract_address).present?
        load_erc20_balance(@wallet.fetch(:address))
      else
        response = client.rest_api(:post, '/get-ether-balance', {address:@wallet.fetch(:address) })
        convert_from_base_unit(response['balance'])
      end
    rescue Ether::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    private

    def load_erc20_balance(address)
      response = client.rest_api(:post, '/get-smart-contract-balance', {contractAddress: contract_address, address:normalize_address(address) })
      convert_from_base_unit(response['balance'])
    end

    def create_eth_transaction!(transaction, options = {})
      currency_options = @currency.fetch(:options).slice(:gas_limit, :gas_price)
      options.merge!(DEFAULT_ETH_FEE, currency_options)
      amount = convert_to_base_unit(transaction.amount)
      
      options[:gas_price] = calculate_gas_price(options)
      # Subtract fees from initial deposit amount in case of deposit collection
      amount -= options.fetch(:gas_limit).to_i * options.fetch(:gas_price).to_i if options.dig(:subtract_fee)
      
      return transaction if amount < 0
      params = {
        to: normalize_address(transaction.to_address),
        amount: amount,
        privKey: @wallet.fetch(:secret),
        gasPrice: '0x' + options.fetch(:gas_price).to_i.to_s(16),
        gasLimit: '0x' + options.fetch(:gas_limit).to_i.to_s(16)
      }


      response = client.rest_api(:post, '/send-transaction', params)
      hash = response.fetch('hash')
      unless hash
        raise Ether::Client::Error, \
              "Withdrawal from #{@wallet.fetch(:address)} to #{transaction.to_address} failed."
      end
      # Make sure that we return currency_code
      transaction.currency_id = 'eth' if transaction.currency_id.blank?
      transaction.amount = convert_from_base_unit(amount)
      transaction.hash = hash
      transaction.options = options
      transaction
    end

    def create_erc20_transaction!(transaction, options = {})
      currency_options = @currency.fetch(:options).slice(:gas_limit, :gas_price, :erc20_contract_address)
      options.merge!(DEFAULT_ERC20_FEE, currency_options)

      amount = convert_to_base_unit(transaction.amount)
      amount_str = amount.to_s

      data = abi_encode('transfer(address,uint256)',
                        normalize_address(transaction.to_address),
                        '0x' + amount.to_s(16))

      if transaction.options.present?
        options[:gas_price] = calculate_gas_price(options)
      else
        options[:gas_price] = calculate_gas_price(options)
      end

      params = {
        contractAddress:options.fetch(:erc20_contract_address),
        to: transaction.to_address,
        amount: amount_str,
        data: data,
        privKey: @wallet.fetch(:secret),
        gasLimit: '0x' + options.fetch(:gas_limit).to_i.to_s(16),
        gasPrice: '0x' + options.fetch(:gas_price).to_i.to_s(16)
      }

      response = client.rest_api(:post, '/send-ERC20-transaction', params)
      txid = response.fetch('hash')

      unless valid_txid?(normalize_txid(txid))
        raise Ether::WalletClient::Error, \
              "Withdrawal from #{@wallet.fetch(:address)} to #{transaction.to_address} failed."
      end
      transaction.hash = normalize_txid(txid)
      transaction.options = options
      transaction
    end

    def normalize_address(address)
      address.downcase
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
      value.to_d / @currency.fetch(:base_factor)
    end

    def convert_to_base_unit(value)
      x = value.to_d * @currency.fetch(:base_factor)
      unless (x % 1).zero?
        raise Peatio::WalletClient::Error,
            "Failed to convert value to base (smallest) unit because it exceeds the maximum precision: " \
            "#{value.to_d} - #{x.to_d} must be equal to zero."
      end
      x.to_i
    end

    def calculate_gas_price(options = { gas_price: :standard })
      gas_price = client.rest_api(:get, '/gas-price', {})
      (gas_price).to_i
    end

    def client
      uri = @wallet.fetch(:uri) { raise Peatio::Wallet::MissingSettingError, :uri }
      @client ||= Client.new(uri, idle_timeout: 1)
    end
  end
end
