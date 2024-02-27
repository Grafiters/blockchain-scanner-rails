module OWHDWallet
  class WalletBTC < WalletAbstract
    def native_currency_code
      'btc'
    end

    def coin_type
      'btc'
    end

    def token_name
      'omni'
    end

    def eth_like?
      false
    end
  end
end
