# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Entities
      class Account < Base
        expose(
          :currency_id,
          as: :currency,
          documentation: {
            desc: 'Currency code.',
            type: String
          }
        )

        expose(
          :balance,
          format_with: :decimal,
          documentation: {
            desc: 'Account balance.',
            type: BigDecimal
          }
        )

        expose(
          :locked,
          format_with: :decimal,
          documentation: {
            desc: 'Account locked funds.',
            type: BigDecimal
          }
        )
        
        expose(
          :logo_url,
          as: :logo_url,
          documentation: {
            desc: 'Logo Url',
            type: String
          }
        ) do |account|
          account.currency[:icon_url]
        end

        expose(
          :logo_url,
          as: :logo_url,
          documentation: {
            desc: 'Logo Url',
            type: String
          }
        ) do |account|
          account.currency[:icon_url]
        end

        expose(
          :deposit_addresses,
          if: ->(account, _options) { account.currency.coin? },
          using: API::V2::Entities::PaymentAddress,
          documentation: {
            desc: 'User deposit addresses',
            is_array: true,
            type: String
          }
        ) do |account, options|
          deposit_wallets = Wallet.active_deposit_wallets(account.currency_id)
          ::PaymentAddress.where(wallet: deposit_wallets, member: options[:current_user], remote: false)
        end

        expose(
          :virtual_account,
          if: ->(account, _options) { account.currency.fiat?},
          using: API::V2::Entities::VirtualAccounts,
          documentation: {
            desc: 'User Virtual account',
            is_array: true,
            type: String
          }
        ) do |account, options|
          member_id = account.member_id
          member_id = options[:current_user] if options[:current_user]
          ::VirtualAccount.where(member_id: member_id)
        end

      end
    end
  end
end
