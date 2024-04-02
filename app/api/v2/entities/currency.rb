# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Entities
      class Currency < Base
        expose(
          :id,
          documentation: {
            desc: 'Currency code.',
            type: String
          }
        )

        expose(
          :status,
          documentation: {
            type: String,
            desc: 'Currency display status (enabled/disabled/hidden).'
          }
        )

        expose(
          :name,
          documentation: {
              type: String,
              desc: 'Currency name'
          },
          if: -> (currency){ currency.name.present? }
        )

        expose(
          :description,
          documentation: {
            type: String,
            desc: 'Currency description'
          }
        )

        expose(
          :homepage,
          documentation: {
            type: String,
            desc: 'Currency homepage'
          }
        )

        expose(
          :price,
          documentation: {
            desc: 'Currency current price'
          }
        )

        expose(
          :type,
          documentation: {
            type: String,
            values: -> { ::Currency.types },
            desc: 'Currency type'
          }
        )

        expose(
          :precision,
          documentation: {
            desc: 'Currency precision'
          }
        )

        expose(
          :position,
          documentation: {
            desc: 'Position used for defining currencies order'
          }
        )

        expose(
          :detail_currencies,
          documentation: {
            desc: "detail_currencies for defining currencies"
          }
        )

        expose(
          :market_cap,
          documentation: {
            desc: "market_cap for defining currencies"
          }
        )

        expose(
          :total_supply,
          documentation: {
            desc: "total_supply for defining currencies"
          }
        )

        expose(
          :circulation_supply,
          documentation: {
            desc: "circulation_supply for defining currencies"
          }
        )


        expose(
          :options,
          documentation: {
            desc: 'Position used for defining currencies order'
          },
          if: -> (currency) { !currency.options.nil? }
        )

        expose(
          :icon_url,
          documentation: {
            desc: 'Currency icon',
            example: 'https://upload.wikimedia.org/wikipedia/commons/0/05/Ethereum_logo_2014.svg'
          },
          if: -> (currency){ currency.icon_url.present? }
        )

        expose(
          :networks,
          using: API::V2::Entities::BlockchainCurrency,
          documentation: {
            type: 'API::V2::Entities::BlockchainCurrency',
            is_array: true,
            desc: 'Currency networks.'
          },
        ) do |c|
          c.blockchain_currencies
        end
      end
    end
  end
end
