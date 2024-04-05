# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Config
      module Entities
        class Withdraw < API::V2::Entities::Withdraw
          expose(
            :member_id,
            as: :member,
            documentation: {
              type: String,
              desc: 'The member id.'
            }
          )

          expose(
            :block_number,
            documentation: {
              type: Integer,
              desc: 'The withdrawal block_number.'
            },
            if: ->(w) { w.currency.coin? }
          )

          expose(
            :tid,
            documentation: {
              type: String,
              desc: 'Withdraw tid.'
            }
          )

          expose(
            :error,
            documentation: {
              type: String,
              desc: 'Withdraw error.'
            },
            unless: ->(w) { w.succeed? }
          )

          expose(
            :metadata,
            documentation: {
              type: String,
              desc: 'Optional metadata to be applied to the transaction.'
            }
          )
        end
      end
    end
  end
end
