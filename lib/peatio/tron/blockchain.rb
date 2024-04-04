module Tron
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

    def process_block!(block_number,to_block_number)
      block = fetch_block!(block_number,to_block_number).first
      return Peatio::Block.new(block_number, []) if block.nil?
      block
    end

    def process_multiple_block!(block_number,to_block_number)
      block = fetch_block!(block_number,to_block_number).first
      return Peatio::Block.new(block_number, []) if block.nil?
      block
    end

    def fetch_block!(block_number,endblock = block_number +1)
      txss = []
      blocks = []
      block_json = client.rest_api(:post, '/get-block-range', {from: block_number,to:endblock})
      Rails.logger.warn block_json.as_json
      block_json.each_with_object([]) do |block, block_arr|
        height = block.fetch('height')
        transactions = block.fetch('txs',[])
        transactions.each_with_object([]) do |txs, txs_arr|
          type = txs.fetch('type')
          contract = txs.fetch('contract')
          txID = txs.fetch('txID')
          from_address = txs.fetch('from_address')
          to_address = txs.fetch('to_address')
          amount = txs.fetch('amount')

          faddress = []
          faddress << from_address
          if(type === 'TRX')
            @eth.map do |currency|
              txss <<  Peatio::Transaction.new(
                        hash:           txID,
                        amount:         convert_from_base_unit(amount,currency),
                        from_addresses: faddress,
                        to_address:     to_address,
                        txout:          1,
                        block_number:   height,
                        currency_id:    currency.fetch(:id),
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
                          currency_id:    currency.fetch(:id),
                          status:         'success')
              end
            end
          end
        end
      end
      blocks << Peatio::Block.new(block_number, txss) unless txss.empty?
      blocks
    rescue Tron::Client::Error => e
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
    rescue Tron::Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    def load_balance_of_address!(address, currency_code)
      currency = settings[:currencies].find { |c| c[:id] == currency_code.to_s }
      raise UndefinedCurrencyError unless currency

      if currency.dig(:options, :erc20_contract_address).present?
        contract_address = currency.dig(:options, :erc20_contract_address)
        if(contract_address.length > 15)
          load_erc20_balance(address,contract_address,currency)
        else
          load_erc10_balance(address,contract_address,currency)
        end
      else
        response = client.rest_api(:post, '/get-tron-balance', {address:address })
        convert_from_base_unit(response['balance'],currency)
      end
    rescue Tron::Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end




    private

    def load_erc20_balance(address,contract_address,currency)
      response = client.rest_api(:post, '/get-trc20-balance', {contractAddress: contract_address, address:address })
      convert_from_base_unit(response['balance'],currency)
    end

    def load_erc10_balance(address,contract_address,currency)
      response = client.rest_api(:post, '/get-trc10-balance', {contractAddress: contract_address, address:address })
      convert_from_base_unit(response['balance'],currency)
    end

    def encode_base58(hex)
      leading_zero_bytes  = (hex.match(/^([0]+)/) ? $1 : '').size / 2
      ("1"*leading_zero_bytes) + int_to_base58( hex.to_i(16) )
    end

    def int_to_base58(int_val, leading_zero_bytes=0)
      alpha = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
      base58_val, base = '', alpha.size
      while int_val > 0
        int_val, remainder = int_val.divmod(base)
        base58_val = alpha[remainder] + base58_val
      end
      base58_val
    end

    def toHex(address)
      bin_pre_sha = [address].pack('H*')
      round_one = Digest::SHA256.hexdigest bin_pre_sha
      round_two = Digest::SHA256.hexdigest [round_one].pack('H*');
      checksum = round_two[0,8];
      pre_base58 = "#{address}#{checksum}"
      base58_key = encode_base58(pre_base58)
      base58_key
    end

    def normalize_address(address)
      address.try(:downcase)
    end

    def client
      @client ||= Tron::Client.new(settings_fetch(:server))
    end

    def settings_fetch(key)
      @settings.fetch(key) { raise Peatio::Blockchain::MissingSettingError, key.to_s }
    end

    def normalize_txid(txid)
      txid.try(:downcase)
    end

    def normalize_address(address)
      address.try(:downcase)
    end

    def contract_address(currency)
      normalize_address(currency.dig(:options, :erc20_contract_address))
    end

    def abi_encode(method, *args)
      '0x' + args.each_with_object(Digest::SHA3.hexdigest(method, 256)[0...8]) do |arg, data|
        data.concat(arg.gsub(/\A0x/, '').rjust(64, '0'))
      end

    end
  end
end
