# encoding: UTF-8
# frozen_string_literal: true

module Workers
  module Daemons
    class Blockchain < Base
      class Runner
        attr_reader :ts, :thread

        def initialize(blockchain, ts)
          @blockchain = blockchain
          @ts = ts
          @thread = nil
        end

        def start
          @thread ||= Thread.new do
            bc_service = BlockchainService.new(@blockchain)

            Rails.logger.info { "Processing #{@blockchain.name} blocks." }

            loop do
              begin
                # Reset blockchain_service state.
                bc_service.reset!

                if @blockchain.reload.height + @blockchain.min_confirmations >= bc_service.latest_block_number
                  Rails.logger.info { "Skip synchronization. No new blocks detected, height: #{@blockchain.height}, latest_block: #{bc_service.latest_block_number}." }
                  Rails.logger.info { "Sleeping for 10 seconds" }
                  sleep(5)
                  next
                end

                from_block = @blockchain.height || 0
                latest_block = bc_service.latest_block_number
                p_block = [latest_block, from_block + 10].min

                if(@blockchain.client === 'tron')
                    if(latest_block - from_block > 3)
                      Rails.logger.warn { "Started processing #{@blockchain.key} from number #{from_block} to #{p_block}" }
                      block_json = bc_service.process_multiple_block(from_block,p_block)
                      bc_service.update_height(p_block)
                      Rails.logger.warn { "Finished processing #{@blockchain.key} block number #{from_block} to #{p_block}" }
                    end
                else
                  (from_block..bc_service.latest_block_number).each do |block_id|
                    Rails.logger.warn { "Started processing #{@blockchain.key} block number #{block_id}." }
                    block_json = bc_service.process_block(block_id)
                    Rails.logger.info { "Fetch #{block_json.transactions.count} transactions in block number #{block_id}." }
                    bc_service.update_height(block_id)
                    Rails.logger.warn { "Finished processing #{@blockchain.key} block number #{block_id}." }
                  end
                end

              rescue StandardError => e
                report_exception(e)
                Rails.logger.warn { "Error: #{e}. Sleeping for 10 seconds" }
                sleep(5)
              end
            end
          end
        end

        def stop
          @thread&.kill
        end
      end

      def run
        @runner_pool = ::Blockchain.where(blockchain_group: ENV.fetch('GROUP_ID')).active.each_with_object({}) do |b, pool|
          max_ts = [b.blockchain_currencies.maximum(:updated_at), b.updated_at].compact.max.to_i
          logger.warn { "Creating the runner for #{b.key}" }
          pool[b.key] = Runner.new(b, max_ts).tap(&:start)
        end

        while running
          begin
            Rails.logger.warn @runner_pool.keys
            Rails.logger.warn ::Blockchain.where(blockchain_group: ENV.fetch('GROUP_ID')).active.pluck(:key)
            # Stop disabled blockchains runners first.
            (@runner_pool.keys - ::Blockchain.where(blockchain_group: ENV.fetch('GROUP_ID')).active.pluck(:key)).each do |b_key|
              logger.warn { "Stopping the runner for #{b_key} (blockchain is not active anymore)" }
              @runner_pool.delete(b_key).stop
            end

            # Recreate active blockchain runners by comparing runner &
            # maximum blockchain & blockchain currencies updated_at timestamp.
            ::Blockchain.where(blockchain_group: ENV.fetch('GROUP_ID')).active.each do |b|
              max_ts = [b.blockchain_currencies.maximum(:updated_at), b.updated_at].compact.max.to_i

              if @runner_pool[b.key].blank?
                logger.warn { "Starting the new runner for #{b.key} (no runner found in pool)" }
                @runner_pool[b.key] = Runner.new(b, max_ts).tap(&:start)
              elsif @runner_pool[b.key].ts < max_ts
                logger.warn { "Recreating a runner for #{b.key} (#{Time.at(@runner_pool[b.key].ts)} < #{Time.at(max_ts)})" }
                @runner_pool.delete(b.key).stop
                @runner_pool[b.key] = Runner.new(b, max_ts).tap(&:start)
              else
                logger.warn { "The runner for #{b.key} is up to date (#{Time.at(@runner_pool[b.key].ts)} >= #{Time.at(max_ts)})" }
              end
            end

            logger.info { "Current runners timestamps:" }
            logger.info do
              @runner_pool.transform_values(&:ts)
            end

            # Check for blockchain config changes in 10 seconds.
            sleep 10

          rescue StandardError => e
            raise e if is_db_connection_error?(e)

            report_exception(e)
            Rails.logger.warn { "Error: #{e}. Sleeping for 10 seconds" }
            sleep(5)
          end
        end
      end

      def stop
        @running = false
        @runner_pool.each { |_bc_key, runner| runner.stop }
      end
    end
  end
end
