module Stellar
  class Blockchain < Peatio::Blockchain::Abstract
    UndefinedCurrencyError = Class.new(StandardError)

    DEFAULT_FEATURES = { case_sensitive: true, cash_addr_format: false }.freeze

    def initialize(custom_features = {})
      @features = DEFAULT_FEATURES.merge(custom_features).slice(*SUPPORTED_FEATURES)
      @settings = {}
    end

    def configure(settings = {})
      # Clean client state during configure.
      @client = nil
      @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))
    end

    def fetch_block!(ledger_index)
      wallet = ::Wallet.where(kind: 100,blockchain_key: 'xlm').first
      address = wallet['address']
      ledger = client.rest_api(:post,'/fetch-block',{height: ledger_index,address: address})
      return Peatio::Block.new(ledger_index, []) if ledger.length === 0
      ledger.each_with_object([]) do |tx, txs_array|
        txs = build_transaction(tx).map do |ntx|
          Peatio::Transaction.new(ntx.merge(block_number: ledger_index))
        end
        txs_array.append(*txs)
        Rails.logger.warn txs.inspect
      end.yield_self { |txs_array| Peatio::Block.new(ledger_index, txs_array) }
    rescue Ripple::Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    def latest_block_number
      client.rest_api(:get, '/get-height').fetch('height')
    rescue Stellar::Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    def load_balance_of_address!(address, currency_code)
      currency = settings[:currencies].find { |c| c[:id] == currency_code.to_s }
      raise UndefinedCurrencyError unless currency
      client.rest_api(:post,'/get-balance',{address: normalize_address(address)})
                      .fetch('balance')
                      .to_d
                      .yield_self { |amount| convert_from_base_unit(amount, currency) }

    rescue Stellar::Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    private
    def build_transaction(tx_hash)
      Rails.logger.warn tx_hash.inspect
      destination_tag = tx_hash['memo']
      address = "#{to_address(tx_hash)}?dt=#{destination_tag}"

      settings_fetch(:currencies).each_with_object([]) do |currency, formatted_txs|
        formatted_txs << { hash: tx_hash['txID'],
                           txout: 1,
                           to_address: address,
                           status: 'success',
                           currency_code: currency[:id],
                           amount: convert_from_base_unit(tx_hash.dig('amount'), currency) }
      end
    end


    def settings_fetch(key)
      @settings.fetch(key) { raise Peatio::Blockchain::MissingSettingError, key.to_s }
    end

    def normalize_address(address)
      address.gsub(/\?dt=\d*\Z/, '')
    end

    def valid_address?(address)
      /\Ar[0-9a-zA-Z]{24,34}(:?\?dt=[1-9]\d*)?\z/.match?(address)
    end

    def to_address(tx)
      normalize_address(tx['to_address'])
    end

    def destination_tag_from(address)
      address =~ /\?dt=(\d*)\Z/
      $1.to_i
    end

    def convert_from_base_unit(value, currency)
      Rails.logger.warn "---------------"
      Rails.logger.warn value
      Rails.logger.warn currency
      Rails.logger.warn "---------------"
      value.to_d / currency.fetch(:base_factor).to_d
    end

    def client
      @client ||= Client.new(settings_fetch(:server))
    end
  end
end
