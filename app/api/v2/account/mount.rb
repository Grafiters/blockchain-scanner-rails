module API::V2
  module Account
    class Mount < Grape::API
      mount Account::Deposits
      mount Account::Withdraws
    end
  end
end
