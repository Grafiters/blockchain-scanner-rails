# encoding: UTF-8
# frozen_string_literal: true

class Withdraw < ApplicationRecord
  STATES = %i[ prepared
               rejected
               accepted
               skipped
               processing
               succeed
               canceled
               failed
               errored
               confirming
               under_review].freeze
  COMPLETED_STATES = %i[succeed rejected canceled failed].freeze
  SUCCEED_PROCESSING_STATES = %i[prepared accepted skipped processing errored confirming succeed under_review].freeze

  include AASM
  include AASM::Locking
  include TIDIdentifiable
  include FeeChargeable

  extend Enumerize

  serialize :error, JSON unless Rails.configuration.database_support_json
  serialize :metadata, JSON unless Rails.configuration.database_support_json

  TRANSFER_TYPES = { fiat: 100, crypto: 200 }

  belongs_to :currency, foreign_key: :currency_id, primary_key: :code, required: true
  belongs_to :blockchain, foreign_key: :blockchain_key, primary_key: :key
  belongs_to :blockchain_coin_currency, -> { where.not(blockchain_key: nil) }, class_name: 'BlockchainCurrency', foreign_key: %i[blockchain_key currency_id], primary_key: %i[blockchain_key currency_id]
  belongs_to :blockchain_fiat_currency, -> { where(blockchain_key: nil) }, class_name: 'BlockchainCurrency', foreign_key: :currency_id, primary_key: :currency_id

  # Optional beneficiary association gives ability to support both in-peatio
  # beneficiaries and managed by third party application.

  after_initialize :initialize_defaults, if: :new_record?
  before_validation { self.completed_at ||= Time.current if completed? }
  before_validation { self.transfer_type ||= currency.coin? ? 'crypto' : 'fiat' }

  validates :rid, :aasm_state, presence: true
  validates :txid, uniqueness: { scope: :currency_id }, if: :txid?
  validates :block_number, allow_blank: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  validates :blockchain_key,
            inclusion: { in: ->(_) { Blockchain.pluck(:key).map(&:to_s) } },
            if: -> { currency.coin? }

  scope :completed, -> { where(aasm_state: COMPLETED_STATES) }
  scope :succeed_processing, -> { where(aasm_state: SUCCEED_PROCESSING_STATES) }

  after_commit on: :update do
    publish_to_event
  end

  aasm whiny_transitions: false do
    state :prepared, initial: true
    state :canceled
    state :accepted
    state :skipped
    state :to_reject
    state :rejected
    state :processing
    state :under_review
    state :succeed
    state :failed
    state :errored
    state :confirming

    event :accept do
      transitions from: :prepared, to: :accepted
      after_commit do
        process!
      end
    end

    event :cancel do
      transitions from: %i[prepared accepted], to: :canceled
    end

    event :reject do
      transitions from: %i[to_reject accepted confirming under_review], to: :rejected
    end

    event :process do
      transitions from: %i[accepted skipped errored], to: :processing
      after :send_coins!
    end

    event :load do
      transitions from: :accepted, to: :confirming do
      end
      after_commit do
        tx = blockchain_currency.blockchain_api.fetch_transaction(self)
        if tx.present?
          success! if tx.status.success?
        end
      end
    end

    event :review do
      transitions from: :processing, to: :under_review
    end

    event :dispatch do
      transitions from: %i[processing under_review], to: :confirming do
      end
    end

    event :success do
      transitions from: %i[confirming errored under_review], to: :succeed do
      end
    end

    event :skip do
      transitions from: :processing, to: :skipped
    end

    event :fail do
      transitions from: %i[processing confirming skipped errored under_review], to: :failed
    end

    event :err do
      transitions from: :processing, to: :errored, after: :add_error
    end
  end

  delegate :protocol, :warning, to: :blockchain

  def initialize_defaults
    self.metadata = {} if metadata.blank?
  end

  def add_error(e)
    if error.blank?
      update!(error: [{ class: e.class.to_s, message: e.message }])
    else
      update!(error: error << { class: e.class.to_s, message: e.message })
    end
  end

  def blockchain_currency
    currency.coin? ? blockchain_coin_currency : blockchain_fiat_currency
  end

  def blockchain_api
    blockchain_currency.blockchain_api
  end

  def confirmations
    return 0 if block_number.blank?
    return blockchain.processed_height - block_number if (blockchain.processed_height - block_number) >= 0
    'N/A'
  rescue StandardError => e
    report_exception(e)
    'N/A'
  end

  def completed?
    aasm_state.in?(COMPLETED_STATES.map(&:to_s))
  end

  def as_json_for_event_api
    { tid:             tid,
      user_id:         member_id,
      rid:             rid,
      currency:        currency_id,
      amount:          amount.to_s('F'),
      fee:             fee.to_s('F'),
      state:           aasm_state,
      created_at:      created_at.iso8601,
      updated_at:      updated_at.iso8601,
      completed_at:    completed_at&.iso8601,
      blockchain_txid: txid }
  end

  def publish_to_event
    RabbitmqService.new({routing_key: 'withdraw.coin_or_token', exchange_name: 'withdraw_coin'}).handling_publish(JSON.dump(as_json_for_event_api))
  end

  private
  def send_coins!
    AMQP::Queue.enqueue(:withdraw_coin, id: id) if currency.coin?
  end
end

# == Schema Information
# Schema version: 20210609094033
#
# Table name: withdraws
#
#  id             :bigint           not null, primary key
#  member_id      :bigint           not null
#  beneficiary_id :bigint
#  currency_id    :string(10)       not null
#  blockchain_key :string(255)
#  amount         :decimal(32, 16)  not null
#  fee            :decimal(32, 16)  not null
#  txid           :string(128)
#  aasm_state     :string(30)       not null
#  block_number   :integer
#  sum            :decimal(32, 16)  not null
#  type           :string(30)       not null
#  transfer_type  :integer
#  tid            :string(64)       not null
#  rid            :string(256)      not null
#  note           :string(256)
#  metadata       :json
#  error          :json
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  completed_at   :datetime
#
# Indexes
#
#  index_withdraws_on_aasm_state            (aasm_state)
#  index_withdraws_on_currency_id           (currency_id)
#  index_withdraws_on_currency_id_and_txid  (currency_id,txid) UNIQUE
#  index_withdraws_on_member_id             (member_id)
#  index_withdraws_on_tid                   (tid)
#  index_withdraws_on_type                  (type)
#
