# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Entities
      class Transactions < Base
        expose(
          :address,
          documentation: {
            type: String,
            desc: 'Recipient address of transaction.'
          }
        )

        expose(
          :currency_id,
          as: :currency,
          documentation: {
            type: String,
            desc: 'Transaction currency id.'
          }
        )

        expose(
          :logo_url,
          as: :logo_url,
          documentation: {
            type: String,
            desc: "The market in which the order is placed, e.g. 'btcusd'."\
                  "All available markets can be found at /api/v2/markets."
          }
        )do |transaction|
          transaction.currency[:icon_url]
        end

        expose(
          :fullname,
          as: :fullname,
          documentation: {
            type: String,
            desc: "The market in which the order is placed, e.g. 'btcusd'."\
                  "All available markets can be found at /api/v2/markets."
          }
        )do |transaction|
          transaction.currency[:name]
        end

        expose(
          :amount,
          documentation: {
            type: BigDecimal,
            desc: 'Transaction amount.'
          }
        )

        expose(
          :fee,
          documentation: {
            type: BigDecimal,
            desc: 'Transaction fee.'
          }
        )

        expose(
          :txid,
          documentation: {
            type: String,
            desc: 'Transaction id.'
          }
        )

        expose(
          :aasm_state,
          as: :state,
          documentation: {
            type: String,
            desc: 'Transaction state.'
          }
        )

        expose(
          :note,
          documentation: {
            type: String,
            desc: 'Withdraw note.'
          }
        )

        expose(
          :confirmations,
          expose_nil: false,
          documentation: {
            type: Integer,
            desc: 'Number of confirmations.'
          }
        )

        expose(
          :created_at,
          format_with: :iso8601,
          documentation: {
            type: String,
            desc: "Transaction created time in iso8601 format."
          }
        )

        expose(
          :updated_at,
          format_with: :iso8601,
          documentation: {
            type: String,
            desc: "Transaction updated time in iso8601 format."
          }
        )

        expose(
          :type,
          documentation: {
            type: String,
            desc: 'Type of transaction'
          }
        ) do |transaction, _options|
            transaction[:type].constantize.superclass.to_s
        end
      end
    end
  end
end
