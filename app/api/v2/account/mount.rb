module API::V2
  module Account
    class Mount < Grape::API
      mount Account::Deposits
      mount Account::Withdraws
      mount Account::Members
    end
  end
end
