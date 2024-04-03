# encoding: UTF-8
# frozen_string_literal: true

# TODO: Rename to DepositAddress
class PaymentAddress < ApplicationRecord
  validates :address, uniqueness: { scope: :wallet_id }, if: :address?

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

  def status
    if address.present?
      # In case when wallet was deleted and payment address still exists in DB
      wallet.present? ? wallet.status : ''
    else
      'pending'
    end
  end

  def trigger_address_event
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
