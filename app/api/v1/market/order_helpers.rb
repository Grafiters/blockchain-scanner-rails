# frozen_string_literal: true

module API
  module V1
    module Market
      module OrderHelpers
        def build_order(offer)
            ::P2pOrder.new \
                p2p_offer_id: offer[:p2p_offer_id],
                p2p_user_id: offer[:p2p_user_id],
                maker_uid: offer[:maker_uid],
                taker_uid: offer[:taker_uid],
                amount: offer[:amount],
                side: offer[:side]
        end

        def create_order(offer)
          order = build_order(offer)
          order.submit_order
          order
        end

        def validation_request
          offer = ::P2pOffer.find_by(offer_number: params[:offer_number])
          if params[:amount] < offer[:min_order_amount] || params[:amount] > offer[:max_order_amount]
            error!({ errors: ['p2p.order.price_order_not_available_for_offer'] }, 422)
          end

          if params[:amount] > offer[:available_amount]
            error!({ errors: ['p2p.order.price_order_not_available_for_offer'] }, 422)
          end
        end
      end
    end
  end
end
