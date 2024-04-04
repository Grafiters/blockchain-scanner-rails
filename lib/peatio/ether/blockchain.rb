module Ether
  class Blockchain < Peatio::Blockchain::Abstract

    UndefinedCurrencyError = Class.new(StandardError)
    TOKEN_EVENT_IDENTIFIER = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'
    SUCCESS = '0x1'
    FAILED = '0x0'
    DEFAULT_FEATURES = { case_sensitive: true, cash_addr_format: false }.freeze

    def initialize(custom_features = {})
      @features = DEFAULT_FEATURES.merge(custom_features).slice(*SUPPORTED_FEATURES)
      @settings = {}
    end

    def configure(settings = {})
      # Clean client state during configure.
      @client = nil
      @erc20 = []; @eth = []

      @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))
      @settings[:currencies]&.each do |c|
        if c.dig(:options, :erc20_contract_address).present?
          @erc20 << c
        else
          @eth << c
        end
      end
    end

    def process_block!(block_number)
      block = fetch_blocks!(block_number).first
      return Peatio::Block.new(block_number, []) if block.nil?
      block
    end

    def fetch_block!(block_number)
      block = fetch_blocks!(block_number).first
      return Peatio::Block.new(block_number, []) if block.nil?
      block
    end

    def fetch_blocks!(block_number)
      txss = []
      blocks = []
      block_json = client.rest_api(:post, '/fetch-block', {height: block_number})
      transactions = block_json.fetch('transactions')
      Rails.logger.warn transactions.as_json
      transactions.each_with_object([]) do |txs, txs_arr|
        height = block_number
        type = txs.fetch('type')
        contract = txs.fetch('contractAddress')
        txID = txs.fetch('txid')
        from_address = txs.fetch('from')
        to_address = txs.fetch('to')
        amount = txs.fetch('amount')

        faddress = []
        faddress << from_address
        if(type === 'Ether')
          @eth.map do |currency|
            txss <<  Peatio::Transaction.new(
                      hash:           txID,
                      amount:         convert_from_base_unit(amount,currency),
                      from_addresses: faddress,
                      to_address:     to_address,
                      txout:          1,
                      block_number:   height,
                      currency_id:    currency.fetch(:id).upcase,
                      status:         'success')
          end
        else
          currencies = @erc20.select { |c| c.dig(:options, :erc20_contract_address) == contract }
          if currencies.length > 0
            currencies.each do |currency|
              txss <<  Peatio::Transaction.new(
                        hash:           txID,
                        amount:         convert_from_base_unit(amount,currency),
                        from_addresses: faddress,
                        to_address:     to_address,
                        txout:          1,
                        block_number:   height,
                        currency_id:    currency.fetch(:id).upcase,
                        status:         'success')
            end
          end
        end
      end
      blocks << Peatio::Block.new(block_number, txss) unless txss.empty?
      blocks
    rescue Ether::Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    def convert_from_base_unit(value, currency)
      value.to_d / currency.fetch(:base_factor).to_d
    end

    def fetch_transaction(txid)
      response = client.rest_api(:post, '/get-transaction', {hash: txid})
    rescue Ether::Client::Error => e
      raise Peatio::Blockchain::ClientError, e  
    end

    def latest_block_number
      response = client.rest_api(:get, '/get-height', {})
      height = response['height']
    rescue Ether::Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    def load_balance_of_address!(address, currency_code)
      currency = settings[:currencies].find { |c| c[:id] == currency_code.to_s }
      raise UndefinedCurrencyError unless currency

      if currency.dig(:options, :erc20_contract_address).present?
        contract_address = currency.dig(:options, :erc20_contract_address)
        load_erc20_balance(address,contract_address,currency)
      else
        response = client.rest_api(:post, '/get-ether-balance', {address:address,visible: true })
        balance = response.fetch('balance',0)
        convert_from_base_unit(balance,currency)
      end
    rescue Ether::Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    private

    def load_erc20_balance(address, currency)
      response = client.rest_api(:post, '/get-smart-contract-balance', {contractAddress: contract_address(currency), address:normalize_address(address) })
      convert_from_base_unit(response['balance'],currency)
    end

    def client
      @client ||= Ether::Client.new(settings_fetch(:server))
    end

    def settings_fetch(key)
      @settings.fetch(key) { raise Peatio::Blockchain::MissingSettingError, key.to_s }
    end

    def normalize_address(address)
      address.try(:downcase)
    end

    def contract_address(currency)
      normalize_address(currency.dig(:options, :erc20_contract_address))
    end

  end
end
