# encoding: UTF-8
# frozen_string_literal: true

# TODO: Rename to DepositAddress
class PaymentAddress < ApplicationRecord
  include Encryptable

  attr_encrypted :secret, :details

  serialize :details, JSON, default: {} unless Rails.configuration.database_support_json

  validates :address, uniqueness: { scope: :wallet_id }, if: :address?

  after_commit :enqueue_address_generation

  belongs_to :wallet
  belongs_to :member
  belongs_to :blockchain, foreign_key: :blockchain_key, primary_key: :key

  before_validation do
    self.blockchain_key = wallet.blockchain_key
  end

  before_validation do
    next if blockchain_api&.case_sensitive?
    self.address = address
  end

  before_validation do
    next unless address? && blockchain_api&.supports_cash_addr_format?
    self.address = CashAddr::Converter.to_cash_address(address)
  end

  def blockchain_api
    BlockchainService.new(blockchain)
  end

  def to_wallet_api_settings
    {
      address: address,
      secret: secret,
      details: details,
      uri: wallet.settings['uri']
    }
  end

  def format_address(format)
    format == 'legacy' ? to_legacy_address : to_cash_address
  end

  def to_legacy_address
    CashAddr::Converter.to_legacy_address(address)
  end

  def to_cash_address
    CashAddr::Converter.to_cash_address(address)
  end

  def enqueue_address_generation
    AMQP::Queue.enqueue(:deposit_coin_address, { member_id: member_id, wallet_id: wallet.id }, { persistent: true })
  end

  def status
    if address.present?
      # In case when wallet was deleted and payment address still exists in DB
      wallet.present? ? wallet.status : ''
    else
      'pending'
    end
  end

  def as_json_publish
    {
      blockchain_key: blockchain_key,
      currencies: wallet.currencies.codes,
      user_id: member_id,
      wallet_id: wallet_id,
      address: address
    }
  end

  def publish_only
    if !address.nil?
      RabbitmqService.new({routing_key: 'deposit.global_address', exchange_name: 'deposit_address'}).handling_publish(as_json_publish)
    end
  end

  def trigger_address_event
    publish_only
    ::AMQP::Queue.enqueue_event('private', member_id, :deposit_address, type: :create,
                                currencies: wallet.currencies.codes,
                                blockchain_key: blockchain_key,
                                address:  address)
  end
end

# == Schema Information
# Schema version: 20210609094033
#
# Table name: payment_addresses
#
#  id                :bigint           not null, primary key
#  member_id         :bigint
#  wallet_id         :bigint
#  blockchain_key    :string(255)
#  address           :string(95)
#  remote            :boolean          default(FALSE), not null
#  secret_encrypted  :string(255)
#  details_encrypted :string(1024)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_payment_addresses_on_member_id  (member_id)
#  index_payment_addresses_on_wallet_id  (wallet_id)
#
