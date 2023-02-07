# encoding: UTF-8
# frozen_string_literal: true

module API
    module V1
      module Account
        module Entities
            class Order < Grape::Entity
                format_with(:iso8601) {|t| t.to_time.in_time_zone(Rails.configuration.time_zone).iso8601 if t }

                expose(
                    :order_number,
                    as: :order_number,
                    documentation: {
                        desc: 'Order Number.',
                        type: String
                    }
                )

                expose(
                    :offer_number,
                    as: :offer_number,
                    documentation: {
                        desc: 'Order Number.',
                        type: String
                    }
                )

                expose(
                    :fiat,
                    as: :fiat,
                    documentation: {
                        desc: 'Order Number.',
                        type: String
                    }
                )
    
                expose(
                    :maker_uid,
                    as: :maker_uid,
                    documentation: {
                        desc: 'Filter Fiat.',
                        type: String
                    }
                )
    
                expose(
                    :taker_uid,
                    as: :taker_uid,
                    documentation: {
                        desc: 'Filter Fiat.',
                        type: String
                    }
                )
    
                expose(
                    :amount,
                    as: :amount,
                    documentation: {
                        desc: 'Filter Fiat.',
                        type: String
                    }
                )

                expose(
                    :available_amount,
                    as: :available_amount,
                    documentation: {
                        desc: 'Filter Fiat.',
                        type: String
                    }
                )

                expose(
                    :origin_amount,
                    as: :origin_amount,
                    documentation: {
                        desc: 'Filter Fiat.',
                        type: String
                    }
                )

                expose(
                    :min_order_amount,
                    as: :min_order_amount,
                    documentation: {
                        desc: 'Order Number.',
                        type: String
                    }
                )

                expose(
                    :max_order_amount,
                    as: :max_order_amount,
                    documentation: {
                        desc: 'Order Number.',
                        type: String
                    }
                )
    
                expose(
                    :state,
                    as: :state,
                    documentation: {
                        desc: 'Filter Fiat.',
                        type: String
                    }
                )
    
                expose(
                    :side,
                    as: :side,
                    documentation: {
                        desc: 'Filter Fiat.',
                        type: String
                    }
                )
    
    
                expose(
                    :created_at,
                    :updated_at,
                    format_with: :iso8601,
                    documentation: {
                        type: String,
                        desc: 'The datetimes for the p2p order.'
                    }
                )
            end
          end
        end
    end
end
  