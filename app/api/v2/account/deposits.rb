# encoding: UTF-8
# frozen_string_literal: true

require_relative '../validations'

module API
  module V2
    module Account
      class Deposits < Grape::API
        desc 'Get your deposits history.',
          is_array: true,
          success: API::V2::Entities::Deposit

        params do
          optional :currency,
            type: String,
            desc: 'Currency code'
          #  values: { value: -> { Currency.visible.codes(bothcase: true) }, message: 'account.currency.doesnt_exist' },
          optional :state,
              desc: 'Filter deposits by states.'
              # values: { value: ->(v) { (Array.wrap(v) - ::Deposit.aasm.states.map(&:name).map(&:to_s)).blank? }, message: 'account.deposit.invalid_state' },
          optional :txid,
                   type: String,
                   allow_blank: false,
                   desc: 'Deposit transaction id.'
          optional :blockchain_key,
              desc: 'Blockchain key of the requested deposit'
              # values: { value: -> { ::Blockchain.pluck(:key) }, message: 'account.deposit.blockchain_key_doesnt_exist' },
          optional :time_from,
                   allow_blank: { value: false, message: 'account.deposit.empty_time_from' },
                   type: { value: Integer, message: 'account.deposit.non_integer_time_from' },
                   desc: 'An integer represents the seconds elapsed since Unix epoch.'
          optional :time_to,
                   type: { value: Integer, message: 'account.deposit.non_integer_time_to' },
                   allow_blank: { value: false, message: 'account.deposit.empty_time_to' },
                   desc: 'An integer represents the seconds elapsed since Unix epoch.'
          optional :limit,
                   type: { value: Integer, message: 'account.deposit.non_integer_limit' },
                   values: { value: 1..100, message: 'account.deposit.invalid_limit' },
                   default: 100,
                   desc: "Number of deposits per page (defaults to 100, maximum is 100)."
          optional :page,
                   type: { value: Integer, message: 'account.deposit.non_integer_page' },
                   values: { value: -> (p){ p.try(:positive?) }, message: 'account.deposit.non_positive_page'},
                   default: 1,
                   desc: 'Page number (defaults to 1).'
        end
        get "/deposits" do
          currency = Currency.find(params[:currency]) if params[:currency].present?

          Deposit.order(id: :desc)
                      .tap { |q| q.where!(currency: currency) if currency }
                      .tap { |q| q.where!(txid: params[:txid]) if params[:txid] }
                      .tap { |q| q.where!(aasm_state: params[:state]) if params[:state] }
                      .tap { |q| q.where!(blockchain_key: params[:blockchain_key]) if params[:blockchain_key] }
                      .tap { |q| q.where!('created_at >= ?', Time.at(params[:time_from])) if params[:time_from].present? }
                      .tap { |q| q.where!('created_at <= ?', Time.at(params[:time_to]+24*60*60)) if params[:time_to].present? }
                      .tap { |q| present paginate(q), with: API::V2::Entities::Deposit }
        end

        desc 'Get details of specific deposit.' do
          success API::V2::Entities::Deposit
        end
        params do
          requires :txid,
                   type: String,
                   allow_blank: false,
                   desc: "Deposit transaction id"
        end
        get "/deposits/:txid" do
          deposit = Deposit.find_by!(txid: params[:txid])
          present deposit, with: API::V2::Entities::Deposit
        end

        desc 'Returns deposit address for account you want to deposit to by currency. ' \
          'The address may be blank because address generation process is still in progress. ' \
          'If this case you should try again later.',
          success: API::V2::Entities::Deposit
        params do
          requires :currency,
                   type: String,
                   desc: 'The account you want to deposit to.'
          requires :user_id,
                  as: :member_id,
                  type: String,
                  desc: "User uid to request identifier"
          optional :blockchain_key,
                   type: String,
                   desc: 'Blockchain key of the requested deposit address'
        end
        post '/deposit_address/:currency', requirements: { currency: /[\w\.\-]+/ } do
          currency = Currency.find_by(code: params[:currency])
          blockchain_currency = BlockchainCurrency.find_by!(currency_id: params[:currency],
            blockchain_key: params[:blockchain_key])
            
          unless blockchain_currency.deposit_enabled?
            error!({ errors: ['account.currency.deposit_disabled'] }, 422)
          end

          wallet = Wallet.active_deposit_wallet(currency.code, blockchain_currency.blockchain_key)
          unless wallet.present?
            error!({ errors: ['account.wallet.not_found'] }, 422)
          end

          pa = PaymentAddress.create!(member_id: params[:member_id], wallet: wallet)

          present pa, with: API::V2::Entities::PaymentAddress, address_format: params[:address_format]
        end
      end
    end
  end
end
