module API
    module V1
        module Market
            class Feedback < Grape::API
                helpers ::API::V1::Admin::Helpers
                helpers ::API::V1::Market::RequestParams
                helpers ::API::V1::Market::OfferHelpers

                # after_save :update_assesment

                namespace :feedback do
                    desc 'desc all Feedback on Order'
                    get '/:order_number' do
                        present paginate(Rails.cache.fetch("trading_fees_#{params}", expires_in: 600) { 
                            ::P2pOrderFeedback.where(order_number: params[:order_number])
                         })
                    end

                    post '/:order_number' do
                        feedback = ::P2pOrderFeedback.create(feedback_params)
                        
                        if feedback.save
                            update_assesment
                        end
                        
                        present feedback
                    end
                end
            end
        end
    end
end