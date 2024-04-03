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
                regexp: { value: URI::regexp, message: 'admin.blockchain.invalid_server' },
                desc: -> { 'Blockchain server url' }
              },
              collection_gas_speed: {
                values: { value: -> { Blockchain::GAS_SPEEDS }, message: 'admin.blockchain.invalid_collection_gas_speed' },
                desc: -> { API::V2::Config::Entities::Blockchain.documentation[:collection_gas_speed][:desc] }
              },
              withdrawal_gas_speed: {
                values: { value: -> { Blockchain::GAS_SPEEDS }, message: 'admin.blockchain.invalid_withdrawal_gas_speed' },
                desc: -> { API::V2::Config::Entities::Blockchain.documentation[:withdrawal_gas_speed][:desc] }
              },
              status: {
                values: { value: %w(active disabled), message: 'admin.blockchain.invalid_status' },
                default: 'active',
                desc: -> { API::V2::Config::Entities::Blockchain.documentation[:status][:desc] }
              },
              min_confirmations: {
                type: { value: Integer, message: 'admin.blockchain.non_integer_min_confirmations' },
                values: { value: -> (p){ p.try(:positive?) }, message: 'admin.blockchain.non_positive_min_confirmations' },
                default: 6,
                desc: -> { API::V2::Config::Entities::Blockchain.documentation[:min_confirmations][:desc] }
              },
              min_deposit_amount: {
                type: { value: BigDecimal, message: 'admin.blockchain.min_deposit_amount' },
                values: { value: -> (p){ p >= 0 }, message: 'admin.blockchain.min_deposit_amount' },
                default: 0.0,
                desc: -> { API::V2::Config::Entities::Blockchain.documentation[:min_deposit_amount][:desc] }
              },
              withdraw_fee: {
                type: { value: BigDecimal, message: 'admin.blockchain.non_decimal_withdraw_fee' },
                values: { value: -> (p){ p >= 0  }, message: 'admin.blockchain.ivalid_withdraw_fee' },
                default: 0.0,
                desc: -> { API::V2::Config::Entities::Blockchain.documentation[:withdraw_fee][:desc] }
              },
              min_withdraw_amount: {
                type: { value: BigDecimal, message: 'admin.blockchain.non_decimal_min_withdraw_amount' },
                values: { value: -> (p){ p >= 0 }, message: 'admin.blockchain.invalid_min_withdraw_amount' },
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
                values: { value: -> { ::Blockchain.pluck(:key) }, message: 'admin.blockchain.blockchain_key_doesnt_exist' },
                desc: -> { API::V2::Config::Entities::Blockchain.documentation[:key][:desc] }
              optional :client,
                values: { value: -> { ::Blockchain.clients.map(&:to_s)  }, message: 'admin.blockchain.blockchain_client_doesnt_exist' },
                desc: -> { API::V2::Config::Entities::Blockchain.documentation[:client][:desc] }
              optional :status,
                values: { value: -> { %w[active disabled] }, message: 'admin.blockchain.blockchain_status_doesnt_exist' },
                desc: -> { API::V2::Config::Entities::Blockchain.documentation[:status][:desc] }
              optional :name,
                values: { value: -> { ::Blockchain.pluck(:name) }, message: 'admin.blockchain.blockchain_name_doesnt_exist' },
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
              requires :id,
                       type: { value: Integer, message: 'admin.blockchain.non_integer_id' },
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:id][:desc] }
            end
            get '/:id' do
              Rails.logger.warn Blockchain.find(params[:id])
              present Blockchain.find(params[:id]), with: API::V2::Config::Entities::Blockchain
            end
  
            desc 'Get a latest blockchain block.'
            params do
              requires :id,
                       type: { value: Integer, message: 'admin.blockchain.non_integer_id' },
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:id][:desc] }
            end
            get '/:id/latest_block' do
              Blockchain.find(params[:id])&.blockchain_api.latest_block_number
            rescue
              error!({ errors: ['admin.blockchain.latest_block'] }, 422)
            end
  
            desc 'Create new blockchain.' do
              success API::V2::Config::Entities::Blockchain
            end
            params do
              use :create_blockchain_params
              requires :key,
                       values: { value: -> (v){ v && v.length < 255 }, message: 'admin.blockchain.key_too_long' },
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:key][:desc] }
              requires :name,
                       values: { value: -> (v){ v && v.length < 255 }, message: 'admin.blockchain.name_too_long' },
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:name][:desc] }
              requires :client,
                       values: { value: -> { ::Blockchain.clients.map(&:to_s) }, message: 'admin.blockchain.invalid_client' },
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:client][:desc] }
              requires :height,
                       type: { value: Integer, message: 'admin.blockchain.non_integer_height' },
                       values: { value: -> (p){ p.try(:positive?) }, message: 'admin.blockchain.non_positive_height' },
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
                       type: { value: Integer, message: 'admin.blockchain.non_integer_id' },
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:id][:desc] }
              optional :key,
                       type: String,
                       values: { value: -> (v){ v.length < 255 }, message: 'admin.blockchain.key_too_long' },
                       coerce_with: ->(v) { v.strip.downcase },
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:key][:desc] }
              optional :name,
                       values: { value: -> (v){ v.length < 255 }, message: 'admin.blockchain.name_too_long' },
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:name][:desc] }
              optional :client,
                       values: { value: -> { ::Blockchain.clients.map(&:to_s) }, message: 'admin.blockchain.invalid_client' },
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:client][:desc] }
              optional :server,
                       regexp: { value: URI::regexp, message: 'admin.blockchain.invalid_server' },
                       desc: -> { 'Blockchain server url' }
              optional :protocol,
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:protocol][:desc] }
              optional :height,
                       type: { value: Integer, message: 'admin.blockchain.non_integer_height' },
                       values: { value: -> (p){ p.try(:positive?) }, message: 'admin.blockchain.non_positive_height' },
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:height][:desc] }
              optional :blockchain_group,
                       desc: -> { 'Blockchain Group' }
            end
            post '/update' do
              blockchain = Blockchain.find(params[:id])
              if blockchain.update(declared(params, include_missing: false))
                Rails.logger.warn blockchain.as_json
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
              requires :blockchian_key,
                       type: { value: String },
                       desc: -> { API::V2::Config::Entities::Blockchain.documentation[:id][:desc] }
              requires :type,
                      type: String,
                      values: { value: -> { %w[block_number ] }, message: 'admin.blockchain.invalid_client' },
                      desc: -> { 'Type data to process' }
              optional :value,
                       type: { value: String, message: 'admin.blockchain.non_integer_block_number' },
                       values: { value: -> (p){ p.try(:positive?) }, message: 'admin.blockchain.non_positive_block_number' },
                       desc: -> { 'The id of a particular block on blockchain' }
            end
            post '/process_block' do
              blockchain = Blockchain.find(params[:id])
              begin
                if blockchain.client == 'tron'
                  blockchain.blockchain_api.process_multiple_block(params[:block_number], params[:block_number])
                else
                  blockchain.blockchain_api.process_block(params[:block_number])
                end
  
                present blockchain, with: API::V2::Config::Entities::Blockchain
                status 201
              rescue StandardError => e
                Rails.logger.error { "Error: #{e} while processing block #{params[:block_number]} of blockchain id: #{params[:id]}" }
                error!({ errors: ['admin.blockchain.process_block'] }, 422)
              end
            end
          end
        end
      end
    end
  end
  