# encoding: UTF-8
# frozen_string_literal: true
require 'yaml'

namespace :seed do
  # TODO: Deprecate seed tasks in favour of import:configs
  desc 'Adds missing currencies to database defined at config/seed/currencies.yml.'
  task currencies: :environment do
    Currency.transaction do
      YAML.load_file(Rails.root.join('config/seed/currencies.yml')).each do |hash|
        
        next if Currency.exists?(code: hash.fetch('code'))
        cur = Currency.create!(hash.merge(code: hash.fetch('code')).except('networks'))
        if hash['networks'].present?
          BlockchainCurrency.transaction do
            hash['networks'].each do |network|
              puts hash.fetch('code')
              next if BlockchainCurrency.exists?(currency_id: hash.fetch('code'), blockchain_key: network.fetch('blockchain_key'))
              BlockchainCurrency.create!(network.merge(currency_id: hash.fetch('code')))
            end
          end
        end
      end
    end
  end

  desc 'Adds missing blockchains to database defined at config/seed/blockchains.yml.'
  task blockchains: :environment do
    Blockchain.transaction do
      YAML.load_file(Rails.root.join('config/seed/blockchains.yml')).each do |hash|
        next if Blockchain.exists?(key: hash.fetch('key'))
        Blockchain.create!(hash)
      end
    end
  end

  desc 'Adds missing wallets to database defined at config/seed/wallets.yml.'
  task wallets: :environment do
    Wallet.transaction do
      YAML.load_file(Rails.root.join('config/seed/wallets.yml')).each do |hash|
        next if Wallet.exists?(name: hash.fetch('name'))
        if hash['currency_ids'].is_a?(String)
          hash['currency_ids'] = hash['currency_ids'].split(',')
        end
        ids = Array.new
        hash['currency_ids'].each do |data|
          curr = Currency.find_by(code: data)
          ids.push(curr[:id])
        end
        hash['currency_ids'] = ids
        puts hash
        Wallet.create!(hash)
      end
    end
  end

end
