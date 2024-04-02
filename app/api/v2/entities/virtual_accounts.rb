# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Entities
      class VirtualAccounts < Base
        expose(
          :currency_id,
          documentation:{
            type: String,
            desc: 'Currency ID'
          }
        )

        expose(
          :bank,
          documentation:{
            type: String,
            desc: 'Bank name'
          }
        )

        expose(
          :number,
          documentation:{
            type: String,
            desc: 'Virtual account number'
          }
        )

        expose(
          :merchant_code,
          documentation:{
            type: String,
            desc: 'Merchant Code'
          }
        )

        expose(
          :name,
          documentation:{
            type: String,
            desc: 'Virtual account name'
          }
        )
      end
    end
  end
end
