# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Account
      class Withdraws < Grape::API

        desc 'List your withdraws as paginated collection.',
          is_array: true,
          success: API::V2::Entities::Withdraw
        params do
          optional :user_id,
                  type: String,
                  as: :member_id,
                  desc: 'User identifier'
          optional :currency,
                  type: String,
                  values: { value: -> { Currency.visible.codes(bothcase: true) }, message: 'account.currency.doesnt_exist'},
                  desc: 'Currency code.'
          optional :blockchain_key,
                  values: { value: -> { ::Blockchain.pluck(:key) }, message: 'account.withdraw.blockchain_key_doesnt_exist' },
                  desc: 'Blockchain key of the requested withdrawal'
          optional :limit,
                  type: { value: Integer, message: 'account.withdraw.non_integer_limit' },
                  values: { value: 1..100, message: 'account.withdraw.invalid_limit' },
                  default: 100,
                  desc: "Number of withdraws per page (defaults to 100, maximum is 100)."
          optional :state,
                  values: { value: ->(v) { (Array.wrap(v) - Withdraw::STATES.map(&:to_s)).blank? }, message: 'account.withdraw.invalid_state' },
                  desc: 'Filter withdrawals by states.'
          optional :rid,
                   type: String,
                   allow_blank: false,
                   desc: 'Wallet address on the Blockchain.'
          optional :time_from,
                   allow_blank: { value: false, message: 'account.withdraw.empty_time_from' },
                   type: { value: Integer, message: 'account.withdraw.non_integer_time_from' },
                   desc: 'An integer represents the seconds elapsed since Unix epoch.'
          optional :time_to,
                   type: { value: Integer, message: 'account.withdraw.non_integer_time_to' },
                   allow_blank: { value: false, message: 'account.withdraw.empty_time_to' },
                   desc: 'An integer represents the seconds elapsed since Unix epoch.'
          optional :page,
                   type: { value: Integer, message: 'account.withdraw.non_integer_page' },
                   values: { value: -> (p){ p.try(:positive?) }, message: 'account.withdraw.non_positive_page'},
                   default: 1,
                   desc: 'Page number (defaults to 1).'
        end
        get '/withdraws' do

          currency = Currency.find_by(id: params[:currency]) if params[:currency].present?

          Withdraw.order(id: :desc)
                      .tap { |q| q.where!(member_id: params[:member_id]) if params[:member_id] }
                      .tap { |q| q.where!(currency: currency) if currency }
                      .tap { |q| q.where!(aasm_state: params[:state]) if params[:state] }
                      .tap { |q| q.where!(rid: params[:rid]) if params[:rid] }
                      .tap { |q| q.where!(blockchain_key: params[:blockchain_key]) if params[:blockchain_key] }
                      .tap { |q| q.where!('created_at >= ?', Time.at(params[:time_from])) if params[:time_from].present? }
                      .tap { |q| q.where!('created_at <= ?', Time.at(params[:time_to]+24*60*60)) if params[:time_to].present? }
                      .tap { |q| present paginate(q), with: API::V2::Entities::Withdraw }
        end

        desc 'Creates new withdrawal to active beneficiary.'
        params do
          requires :currency,
                   type: String,
                   values: { value: -> { Currency.visible.codes(bothcase: true) }, message: 'account.currency.doesnt_exist'},
                   desc: 'The currency code.'
          requires :user_id,
                  as: :member_id,
                  type: String,
                  desc: 'Who will doing withdraw'
          requires :to_address,
                  type: String,
                  desc: 'Destination address will receive'
          requires :amount,
                   type: { value: BigDecimal, message: 'account.withdraw.non_decimal_amount' },
                   values: { value: ->(v) { v.try(:positive?) }, message: 'account.withdraw.non_positive_amount' },
                   desc: 'The amount to withdraw.'
          requires :blockchain_key,
                  values: { value: -> { ::Blockchain.pluck(:key) }, message: 'account.withdraw.blockchain_key_doesnt_exist' },
                  type: String,
                  desc: 'key network will used'
        end
        post '/withdraws' do
          currency = Currency.find_by(code: params[:currency])

          blockchain_currency = BlockchainCurrency.find_by!(currency_id: params[:currency],
                                                            blockchain_key: params[:blockchain_key])
          unless blockchain_currency.withdrawal_enabled?
            error!({ errors: ['account.currency.withdrawal_disabled'] }, 422)
          end

          # TODO: Delete subclasses from Deposit and Withdraw
          withdraw = "withdraws/coin".camelize.constantize.new \
            sum:            params[:amount],
            member_id:      params[:member_id],
            currency:       currency,
            note:           '',
            rid:            params[:to_address],
            blockchain_key: params[:blockchain_key]
          withdraw.save!
          
          withdraw.accept!

          present withdraw, with: API::V2::Entities::Withdraw
        rescue ActiveRecord::RecordInvalid => e
          report_api_error(e, request)

          error!({ errors: ['account.withdraw.invalid_amount'] }, 422)
        rescue => e
          report_exception(e)
          error!({ errors: ['account.withdraw.create_error'] }, 422)
        end

        desc 'Take an action on the withdrawal.',
             success: API::V2::Config::Entities::Withdraw
        params do
          requires :tid,
                   type: Integer,
                   desc: -> { API::V2::Config::Entities::Withdraw.documentation[:id][:desc] }
          requires :action,
                   type: String,
                   values: { value: -> { ::Withdraw.aasm.events.map(&:name).map(&:to_s) }, message: 'admin.withdraw.invalid_action' },
                   desc: "Valid actions are #{::Withdraw.aasm.events.map(&:name)}."
          given action: ->(action) { %w[load dispatch success].include?(action) } do
            optional :txid,
                     type: String,
                     desc: -> { API::V2::Config::Entities::Withdraw.documentation[:blockchain_txid][:desc] }
          end
        end
        post '/withdraws/actions' do
          declared_params = declared(params, include_missing: false)
          withdraw = Withdraw.find_by(tid: declared_params[:tid])

          transited = withdraw.transaction do
            withdraw.update!(txid: declared_params[:txid]) if declared_params[:txid].present?
            withdraw.public_send("#{declared_params[:action]}!").tap do |success|
              raise ActiveRecord::Rollback unless success
            end
          rescue StandardError
            raise ActiveRecord::Rollback
          end

          if transited
            present withdraw, with: API::V2::Config::Entities::Withdraw
          else
            body errors: ["withdraw.cannot_#{declared_params[:action]}"]
            status 422
          end
        end
      end
    end
  end
end
