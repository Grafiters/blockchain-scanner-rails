# encoding: UTF-8
# frozen_string_literal: true

require_relative '../validations'

module API
  module V2
    module Account
      class Deposits < Grape::API

        before { deposits_must_be_permitted! }

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
          user_authorize! :read, ::Deposit

          currency = Currency.find(params[:currency]) if params[:currency].present?

          current_user.deposits.order(id: :desc)
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
          user_authorize! :read, ::Deposit

          deposit = current_user.deposits.find_by!(txid: params[:txid])
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
                  #  values: { value: -> { Currency.visible.codes(bothcase: true) }, message: 'account.currency.doesnt_exist'},
          optional :blockchain_key,
                   type: String,
                   desc: 'Blockchain key of the requested deposit address'
          given :currency do
            optional :address_format,
                     type: String,
                     values: { value: -> { %w[legacy cash] }, message: 'account.deposit_address.invalid_address_format' },
                     validate_currency_address_format: { value: true, prefix: 'account.deposit_address' },
                     desc: 'Address format legacy/cash'
          end
        end
        get '/deposit_address/:currency', requirements: { currency: /[\w\.\-]+/ } do
          user_authorize! :read, ::PaymentAddress

          currency = Currency.find(params[:currency])
          if currency.type == 'fiat'
            connection = Faraday.new(ENV.fetch('PG_URL')) do |c|
                c.use Faraday::Request::BasicAuthentication, ENV.fetch('PG_KEY'), ''
                c.use Faraday::Adapter::NetHttp
                c.request :json
                c.response :json
            end
            c = Faraday.new(
              url: ENV.fetch('ACCOUNT_URL'),
              headers: {'Content-Type' => 'application/json'}
            )
            r = c.post('/api/v2/account/public/uid') do |req|
              req.body = {token: ENV.fetch('ACCESS_TOKEN'),uid: current_user.uid}.to_json
            end
            res = JSON.parse(r.body)

            if res['profiles'].length === 0
              error!({ errors: ['Please confirm your account'] }, 422)
            end
            if res['profiles']
              profile= res['profiles'].last
              full_name= profile['first_name'].to_s + " " + profile['last_name'].to_s
              va = VirtualAccount.where(member_id: current_user.id)
              if va.length == 0
                bank_arr = ENV.fetch("PG_BANK",'').to_s.split(',')
                bank_arr.each { |bank|
                  body = {name: full_name, bank_code: bank, external_id: "VA_"+bank.upcase+"_"+current_user.uid}.to_json
                  response = connection.post('/callback_virtual_accounts') do |req|
                    req.headers['Content-Type'] = 'application/json'
                    req.body = body
                  end
                  data = response.body
                  VirtualAccount.create(member_id: current_user.id, currency_id: currency.id, bank: bank, number: data['account_number'], state: 'active', expired: data['expiration_date'], external_id: data['external_id'], merchant_code: data['merchant_code'],name: data['name'])
                }
              end
              account = VirtualAccount.where(member_id: current_user.id)
              present account, with: API::V2::Entities::VirtualAccounts
            else
              error!({ errors: ['account is not activated'] }, 422)
            end
          else
            blockchain_currency = BlockchainCurrency.find_by!(currency_id: params[:currency],
              blockchain_key: params[:blockchain_key])
              unless blockchain_currency.deposit_enabled?
                error!({ errors: ['account.currency.deposit_disabled'] }, 422)
              end

              wallet = Wallet.active_deposit_wallet(currency.id, blockchain_currency.blockchain_key)
              unless wallet.present?
                error!({ errors: ['account.wallet.not_found'] }, 422)
              end

              payment_address = current_user.payment_address(wallet.id)
              present payment_address, with: API::V2::Entities::PaymentAddress, address_format: params[:address_format]
          end

        end
      end
    end
  end
end
