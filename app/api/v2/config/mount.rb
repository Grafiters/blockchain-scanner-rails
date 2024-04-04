module API::V2
    module Config
      class Mount < Grape::API
        mount Config::Blockchains
        mount Config::Wallets
      end
    end
  end
  