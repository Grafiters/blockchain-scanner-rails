# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Config
      module Entities
        class Wallet < API::V2::Entities::Base
          expose(
            :id,
            documentation:{
              type: Integer,
              desc: 'Unique wallet identifier in database.'
            }
          )

          expose(
            :name,
            documentation: {
                type: String,
                desc: 'Wallet name.'
            }
          )

          expose(
            :kind,
            documentation: {
                type: String,
                desc: "Kind of wallet 'deposit','fee','hot','warm' or 'cold'."
            }
          )

          expose(
            :protocol,
            documentation: {
              desc: 'Blockchain protocol',
            },
            if: -> (wallet) { wallet.blockchain.present? }
          ) { |wallet| wallet.blockchain.protocol }

          expose :currency_ids,
            as: :currencies,
            documentation: {
                is_array: true,
                desc: 'Wallet currency code.',
                example: -> { ::Currency.visible.codes }
            } do |wal|
              wal.currencies.pluck(:code)
            end

          expose(
            :address,
            documentation: {
                type: String,
                desc: 'Wallet address.'
            }
          )

          expose(
            :gateway,
            documentation: {
                type: String,
                desc: 'Wallet gateway.'
            }
          )

          expose(
            :max_balance,
            documentation: {
                type: BigDecimal,
                desc: 'Wallet max balance.'
            }
          )

          expose(
            :balance,
            documentation: {
              type: BigDecimal,
              desc: 'Wallet balance'
            }
          )

          expose(
            :blockchain_key,
            documentation: {
                type: String,
                desc: 'Wallet blockchain key.'
            }
          )

          expose :collect_status,
                documentation: {
                  type: String,
                  desc: 'Collect status is referance from collect payer user address status'
                } do |wallet|
                  wallet.collect_payer_fee_status?
                end
                
          expose(
            :status,
            documentation: {
                type: String,
                desc: 'Wallet status (active/disabled).'
            }
          )

          expose(
            :created_at,
            format_with: :iso8601,
            documentation: {
              type: String,
              desc: 'Wallet created time in iso8601 format.'
            }
          )

          expose(
            :updated_at,
            format_with: :iso8601,
            documentation: {
              type: String,
              desc: 'Wallet updated time in iso8601 format.'
            }
          )
        end
      end
    end
  end
end
