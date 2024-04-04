# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Config
      class Blockchains < Grape::API
        helpers ::API::V2::Config::Helpers

        helpers do
          # Collection of shared params, used to
          # generate required/optional Grape params.
          OPTIONAL_BLOCKCHAIN_PARAMS ||= {
            explorer_transaction: {
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:explorer_transaction][:desc] }
            },
            explorer_address: {
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:explorer_address][:desc] }
            },
            warning: {
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:warning][:desc] }
            },
            blockchain_group: {
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:warning][:desc] }
            },
            description: {
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:description][:desc] }
            },
            server: {
              regexp: { value: URI::regexp, message: 'blockchain.invalid_server' },
              desc: -> { 'Blockchain server url' }
            },
            collection_gas_speed: {
              values: { value: -> { Blockchain::GAS_SPEEDS }, message: 'blockchain.invalid_collection_gas_speed' },
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:collection_gas_speed][:desc] }
            },
            withdrawal_gas_speed: {
              values: { value: -> { Blockchain::GAS_SPEEDS }, message: 'blockchain.invalid_withdrawal_gas_speed' },
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:withdrawal_gas_speed][:desc] }
            },
            status: {
              values: { value: %w(active disabled), message: 'blockchain.invalid_status' },
              default: 'active',
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:status][:desc] }
            },
            min_confirmations: {
              type: { value: Integer, message: 'blockchain.non_integer_min_confirmations' },
              values: { value: -> (p){ p.try(:positive?) }, message: 'blockchain.non_positive_min_confirmations' },
              default: 6,
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:min_confirmations][:desc] }
            },
            min_deposit_amount: {
              type: { value: BigDecimal, message: 'blockchain.min_deposit_amount' },
              values: { value: -> (p){ p >= 0 }, message: 'blockchain.min_deposit_amount' },
              default: 0.0,
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:min_deposit_amount][:desc] }
            },
            withdraw_fee: {
              type: { value: BigDecimal, message: 'blockchain.non_decimal_withdraw_fee' },
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.ivalid_withdraw_fee' },
              default: 0.0,
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:withdraw_fee][:desc] }
            },
            min_withdraw_amount: {
              type: { value: BigDecimal, message: 'blockchain.non_decimal_min_withdraw_amount' },
              values: { value: -> (p){ p >= 0 }, message: 'blockchain.invalid_min_withdraw_amount' },
              default: 0.0,
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:min_withdraw_amount][:desc] }
            },
          }

          params :create_blockchain_params do
            OPTIONAL_BLOCKCHAIN_PARAMS.each do |key, params|
              optional key, params
            end
          end

          params :update_blockchain_params do
            OPTIONAL_BLOCKCHAIN_PARAMS.each do |key, params|
              optional key, params.except(:default)
            end
          end
        end

        namespace :blockchains do
          desc 'Get all blockchains, result is paginated.',
            is_array: true,
            success: API::V2::Config::Entities::Blockchain
          params do
            optional :key,
              values: { value: -> { ::Blockchain.pluck(:key) }, message: 'blockchain.blockchain_key_doesnt_exist' },
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:key][:desc] }
            optional :client,
              values: { value: -> { ::Blockchain.clients.map(&:to_s)  }, message: 'blockchain.blockchain_client_doesnt_exist' },
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:client][:desc] }
            optional :status,
              values: { value: -> { %w[active disabled] }, message: 'blockchain.blockchain_status_doesnt_exist' },
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:status][:desc] }
            optional :name,
              values: { value: -> { ::Blockchain.pluck(:name) }, message: 'blockchain.blockchain_name_doesnt_exist' },
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:name][:desc] }
            use :pagination
            use :ordering
          end
          get do
            ransack_params = Helpers::RansackBuilder.new(params)
                                .eq(:key, :client, :status, :name)
                                .build

            group = ::Blockchain.select("blockchain_group").group(:blockchain_group).pluck(:blockchain_group)

            search = ::Blockchain.ransack(ransack_params)
            search.sorts = "#{params[:order_by]} #{params[:ordering]}"
            
            present :group, group
            present :data, paginate(search.result), with: API::V2::Config::Entities::Blockchain
          end

          desc 'Get available blockchain clients.',
            is_array: true
          get '/clients' do
            Blockchain.clients
          end

          desc 'Get a blockchain.' do
            success API::V2::Config::Entities::Blockchain
          end
          params do
            requires :blockchain_key,
                      type: { value: Integer, message: 'blockchain.non_integer_id' },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:id][:desc] }
          end
          get '/:blockchain_key' do
            present Blockchain.find_by(key: params[:blockchain_key]), with: API::V2::Config::Entities::Blockchain
          end

          desc 'Get a latest blockchain block.'
          params do
            requires :blockchain_key,
                      type: { value: Integer, message: 'blockchain.non_integer_id' },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:id][:desc] }
          end
          get '/:blockchain_key/latest_block' do
            Blockchain.find_by(key: params[:blockchain_key])&.blockchain_api.latest_block_number
          rescue
            error!({ errors: ['blockchain.latest_block'] }, 422)
          end

          desc 'Create new blockchain.' do
            success API::V2::Config::Entities::Blockchain
          end
          params do
            use :create_blockchain_params
            requires :key,
                      values: { value: -> (v){ v && v.length < 255 }, message: 'blockchain.key_too_long' },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:key][:desc] }
            requires :name,
                      values: { value: -> (v){ v && v.length < 255 }, message: 'blockchain.name_too_long' },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:name][:desc] }
            requires :client,
                      values: { value: -> { ::Blockchain.clients.map(&:to_s) }, message: 'blockchain.invalid_client' },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:client][:desc] }
            requires :height,
                      type: { value: Integer, message: 'blockchain.non_integer_height' },
                      values: { value: -> (p){ p.try(:positive?) }, message: 'blockchain.non_positive_height' },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:height][:desc] }
            requires :protocol,
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:protocol][:desc] }
            optional :blockchain_group,
                      desc: -> { 'Blockchain Group' }
          end
          post '/new' do
            blockchain = Blockchain.new(declared(params))
            if blockchain.save
              present blockchain, with: API::V2::Config::Entities::Blockchain
              status 201
            else
              body errors: blockchain.errors.full_messages
              status 422
            end
          end

          desc 'Update blockchain.' do
            success API::V2::Config::Entities::Blockchain
          end 
          params do
            use :update_blockchain_params
            requires :id,
                      type: { value: Integer, message: 'blockchain.non_integer_id' },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:id][:desc] }
            optional :key,
                      type: String,
                      values: { value: -> (v){ v.length < 255 }, message: 'blockchain.key_too_long' },
                      coerce_with: ->(v) { v.strip.downcase },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:key][:desc] }
            optional :name,
                      values: { value: -> (v){ v.length < 255 }, message: 'blockchain.name_too_long' },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:name][:desc] }
            optional :client,
                      values: { value: -> { ::Blockchain.clients.map(&:to_s) }, message: 'blockchain.invalid_client' },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:client][:desc] }
            optional :server,
                      regexp: { value: URI::regexp, message: 'blockchain.invalid_server' },
                      desc: -> { 'Blockchain server url' }
            optional :protocol,
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:protocol][:desc] }
            optional :height,
                      type: { value: Integer, message: 'blockchain.non_integer_height' },
                      values: { value: -> (p){ p.try(:positive?) }, message: 'blockchain.non_positive_height' },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:height][:desc] }
            optional :blockchain_group,
                      desc: -> { 'Blockchain Group' }
          end
          post '/update' do
            blockchain = Blockchain.find(params[:id])
            if blockchain.update(declared(params, include_missing: false))
              present blockchain, with: API::V2::Config::Entities::Blockchain
            else
              body errors: blockchain.errors.full_messages
              status 422
            end
          end

          desc 'Process blockchain\'s block.' do
            success API::V2::Config::Entities::Blockchain
          end
          params do
            requires :blockchain_key,
                      type: { value: String },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:key][:desc] }
            requires :type,
                    type: String,
                    default: 'block_number',
                    values: { value: -> { %w[block_number txid] }, message: 'blockchain.type_scanning' },
                    desc: -> { 'Type data to process' }
            requires :value,
                      type: { value: String },
                      desc: -> { 'The id of a particular block on blockchain' }
          end
          post '/scan-deposit-by-block-number' do
            blockchain = Blockchain.find_by(key: params[:blockchain_key], status: 'active')
            if params[:type] == 'block_number'
              error!({errors: 'blockchain.scan.value_invalid_format'}) if !params[:value].is_a? Integer
            end
            begin
              RabbitmqService.new({routing_key: 'blockchain.fetch_block', exchange_name: 'blockchain'}).handling_publish(JSON.dump(params))

              present blockchain, with: API::V2::Config::Entities::Blockchain
              status 201
            rescue StandardError => e
              Rails.logger.error { "Error: #{e} while processing block #{params[:block_number]} of blockchain id: #{params[:id]}" }
              error!({ errors: ['blockchain.process_block'] }, 422)
            end
          end

          desc 'Process blockchain\'s block.' do
            success API::V2::Config::Entities::Blockchain
          end
          params do
            requires :blockchain_key,
                      type: { value: String },
                      desc: -> { API::V2::Config::Entities::Blockchain.documentation[:key][:desc] }
            requires :type,
                    type: String,
                    default: 'txid',
                    values: { value: -> { %w[block_number txid] }, message: 'blockchain.type_scanning' },
                    desc: -> { 'Type data to process' }
            requires :value,
                      type: { value: String },
                      desc: -> { 'The id of a particular block on blockchain' }
          end
          post '/scan-deposit-by-tx-hash' do
            blockchain = Blockchain.find_by(key: params[:blockchain_key], status: 'active')
            begin
              RabbitmqService.new({routing_key: 'blockchain.fetch_block', exchange_name: 'blockchain'}).handling_publish(JSON.dump(params))

              present blockchain, with: API::V2::Config::Entities::Blockchain
              status 201
            rescue StandardError => e
              Rails.logger.error { "Error: #{e} while processing block #{params[:block_number]} of blockchain id: #{params[:id]}" }
              error!({ errors: ['blockchain.process_block'] }, 422)
            end
          end

          desc 'Get list of crypto currencies' do
            success API::V2::Config::Entities::Currency
          end
          params do
            requires :blockchain_key,
              type: String,
              values: { value: -> { ::Blockchain.pluck(:key) }, message: 'blockchain.blockchain_key_doesnt_exist' },
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:key][:desc] }
            optional :type,
              type: String,
              values: { value: -> { %w[native token] }, message: 'blockchain.invalid_type' },
              desc: -> { API::V2::Config::Entities::Currency.documentation[:type][:desc] }
            optional :smart_contract,
              type: String,
              desc: 'Smart Contract when token'
            optional :status,
              type: String,
              values: { value: -> { %w[enabled disabled] }, message: 'blockchain.invalid_status' },
              desc: -> { API::V2::Config::Entities::Currency.documentation[:status][:desc] }
          end
          get ":blockchain_key/crypto-currencies" do
            Currency.order(position: :asc)
              .tap { |q| q.where('options LIKE ?', 'contract_address') if params[:type] }
              .tap { |q| q.where('options LIKE ?', params[:smart_contract]) if params[:smart_contract] }
              .tap { |q| q.where(status: params[:status]) if params[:status] }
              .tap { |q| q.joins(:blockchin_currencies).where(blockchain_currencies: { blockchain_key: params[:blockchain_key] }) if params[:blockchain_key] }
              .tap { |q| present q, with: API::V2::Config::Entities::Currency }
          end

          desc 'Get list of crypto currencies' do
            success API::V2::Config::Entities::Currency
          end
          params do
            requires :blockchain_key,
              type: String,
              values: { value: -> { ::Blockchain.pluck(:key) }, message: 'blockchain.blockchain_key_doesnt_exist' },
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:key][:desc] }
            requires :currency_code,
              type: String,
              desc: -> { API::V2::Config::Entities::Currency.documentation[:code][:desc] }
            requires :currency_name,
              type: String,
              desc: -> { API::V2::Config::Entities::Currency.documentation[:name][:desc] }
            requires :status,
              type: String,
              default: 'disabled',
              values: { value: -> { %w[enabled disabled] }, message: 'blockchain.invalid_status' },
              desc: -> { API::V2::Config::Entities::Currency.documentation[:status][:desc] }
            requires :base_factor_network,
              type: Integer,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_base_factor' },
              desc: -> { API::V2::Config::Entities::Currency.documentation[:status][:desc] }
            requires :gas_limit,
              type: Integer,
              default: 1000000,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_gas_limit' },
              desc: 'Gas limit on network token or currencies'
            requires :gas_price,
              type: Integer,
              default: 25000,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_gas_price' },
              desc: 'Gas Price on network token or currencies'
            optional :deposit_fee,
              type: BigDecimal,
              default: 0.0,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_deposit_fee' },
              desc: -> { API::V2::Config::Entities::BlockchainCurrency.documentation[:deposit_fee][:desc] }
            optional :min_deposit_amount,
              type: BigDecimal,
              default: 0.0,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_min_deposit_amount' },
              desc: -> { API::V2::Config::Entities::BlockchainCurrency.documentation[:min_deposit_amount][:desc] }
            optional :withdraw_fee,
              type: BigDecimal,
              default: 0.0,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_withdraw_fee' },
              desc: -> { API::V2::Config::Entities::BlockchainCurrency.documentation[:withdraw_fee][:desc] }
            optional :min_withdraw_amount,
              type: BigDecimal,
              default: 0.0,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_min_withdraw_amount' },
              desc: -> { API::V2::Config::Entities::BlockchainCurrency.documentation[:min_withdraw_amount][:desc] }
            optional :smart_contract,
              type: String,
              desc: 'Smart contract when token'
          end
          post ":blockchain_key/crypto-currencies" do
            currency = Currency.find_by(code: params[:currency_code])
            error!({ errors: 'currency.exists' }) if currency.present?
            
            curr_params = {
              code: params[:currency_code],
              name: params[:currency_name],
              type: 'coin',
              status: params[:status],
              precision: 8
            }

            ActiveRecord::Base.transaction do
              currency = Currency.new(curr_params)
              if currency.save
                block_params = {
                  blockchain_key: params[:blockchain_key],
                  currency_id: currency.code,
                  base_factor: 10 ** params[:base_factor_network],
                  deposit_fee: params[:deposit_fee],
                  min_deposit_amount: params[:min_deposit_amount],
                  withdraw_fee: params[:withdraw_fee],
                  min_withdraw_amount: params[:min_withdraw_amount],
                  options: {
                    gas_limit: params[:gas_price],
                    gas_price: params[:gas_limit],
                    erc20_contract_address: params[:smart_contract]
                  }
                }
                bc = BlockchainCurrency.new(block_params)
                if bc.save
                  present currency, with: API::V2::Config::Entities::Currency
                end
              end
            rescue => e
              Rails.logger.warn e.inspect
              raise ActiveRecord::Rollback
              error!({ errors: e })
            end
          end
          desc 'Get list of crypto currencies' do
            success API::V2::Config::Entities::Currency
          end
          params do
            requires :blockchain_key,
              type: String,
              values: { value: -> { ::Blockchain.pluck(:key) }, message: 'blockchain.blockchain_key_doesnt_exist' },
              desc: -> { API::V2::Config::Entities::Blockchain.documentation[:key][:desc] }
            requires :currency_code,
              type: String,
              desc: -> { API::V2::Config::Entities::Currency.documentation[:code][:desc] }
            requires :currency_name,
              type: String,
              desc: -> { API::V2::Config::Entities::Currency.documentation[:name][:desc] }
            requires :status,
              type: String,
              default: 'disabled',
              values: { value: -> { %w[enabled disabled] }, message: 'blockchain.invalid_status' },
              desc: -> { API::V2::Config::Entities::Currency.documentation[:status][:desc] }
            requires :base_factor_network,
              type: Integer,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_base_factor' },
              desc: -> { API::V2::Config::Entities::Currency.documentation[:status][:desc] }
            requires :gas_limit,
              type: Integer,
              default: 1000000,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_gas_limit' },
              desc: 'Gas limit on network token or currencies'
            requires :gas_price,
              type: Integer,
              default: 25000,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_gas_price' },
              desc: 'Gas Price on network token or currencies'
            optional :deposit_fee,
              type: BigDecimal,
              default: 0.0,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_deposit_fee' },
              desc: -> { API::V2::Config::Entities::BlockchainCurrency.documentation[:deposit_fee][:desc] }
            optional :min_deposit_amount,
              type: BigDecimal,
              default: 0.0,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_min_deposit_amount' },
              desc: -> { API::V2::Config::Entities::BlockchainCurrency.documentation[:min_deposit_amount][:desc] }
            optional :withdraw_fee,
              type: BigDecimal,
              default: 0.0,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_withdraw_fee' },
              desc: -> { API::V2::Config::Entities::BlockchainCurrency.documentation[:withdraw_fee][:desc] }
            optional :min_withdraw_amount,
              type: BigDecimal,
              default: 0.0,
              values: { value: -> (p){ p >= 0  }, message: 'blockchain.non_positive_min_withdraw_amount' },
              desc: -> { API::V2::Config::Entities::BlockchainCurrency.documentation[:min_withdraw_amount][:desc] }
            optional :smart_contract,
              type: String,
              desc: 'Smart contract when token'
          end
          post ":blockchain_key/crypto-currencies/update" do
            currency = Currency.find_by(code: params[:currency_code])
            error!({ errors: 'currency.not_exists' }) if !currency.present?
            
            curr_params = {
              code: params[:currency_code] || currency[:code],
              name: params[:currency_name] || currency[:name],
              type: 'coin',
              status: params[:status] || currency[:status],
              precision: 8
            }
            bc = BlockchainCurrency.find_by(blockchain_key: params[:blockchain_key], currency_id: curr_params[:code])
            error!({ errors: 'blockchain_currency.not_exists' }) if !currency.present?

            ActiveRecord::Base.transaction do
              if currency.update(curr_params)
                bc = BlockchainCurrency.find_by(blockchain_key: params[:blockchain_key], currency_id: curr_params[:code])

                block_params = {
                  blockchain_key: params[:blockchain_key] || bc[:blockchain_key],
                  currency_id: currency.code || bc[:code],
                  base_factor: 10 ** params[:base_factor_network] || bc[:base_factor_network],
                  deposit_fee: params[:deposit_fee] || bc[:deposit_fee],
                  min_deposit_amount: params[:min_deposit_amount] || bc[:min_deposit_amount],
                  withdraw_fee: params[:withdraw_fee] || bc[:withdraw_fee],
                  min_withdraw_amount: params[:min_withdraw_amount] || bc[:min_withdraw_amount],
                  options: {
                    gas_limit: params[:gas_price],
                    gas_price: params[:gas_limit],
                    erc20_contract_address: params[:smart_contract]
                  }
                }
                if bc.update(block_params)
                  present currency, with: API::V2::Config::Entities::Currency
                end
              end
            rescue => e
              Rails.logger.warn e.inspect
              raise ActiveRecord::Rollback
              error!({ errors: e })
            end
          end
        end
      end
    end
  end
end
  