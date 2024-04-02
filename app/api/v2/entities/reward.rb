module API
    module V2
        module Entities
            class Reward < Base
                expose :uid,
                    documentation: {
                        type: String,
                        desc: "uid for reward data"
                    }

                expose :refferal_member_id,
                    as: :refferal,
                    using: API::V2::Entities::Member,
                    documentation: {
                        type: String,
                        desc: "member who reward from"
                    } do |reward|
                        reward.refferal
                    end

                expose :reffered_member_id,
                    as: :reffered,
                    using: API::V2::Entities::Member,
                    documentation: {
                        type: String,
                        desc: "who reward member for"
                    } do |reward|
                        reward.reffered
                    end

                expose :reference,
                    documentation: {
                        type: String,
                        desc: "currency for reward data"
                    }
            
                expose :reference_data,
                    if: -> (reward) { reward.reference == 'Trade' },
                    documentation: {
                        type: API::V2::Entities::Trade,
                        desc: "Market source to get reward"
                    } do |reward|
                        API::V2::Entities::Trade.represent(reward.get_trade, current_user: reward.reffered)
                    end

                expose :market,
                    if: -> (reward) { reward.reference == 'Trade' },
                    using: API::V2::Entities::Market,
                    documentation: {
                        type: String,
                        desc: "Market source to get reward"
                    } do |reward|
                        reward.get_market
                    end

                expose :amount,
                    documentation: {
                        type: String,
                        desc: "amount for reward data"
                    }

                expose :currency,
                    documentation: {
                        type: String,
                        desc: "currency for reward data"
                    }

                expose :type,
                    documentation: {
                        type: String,
                        desc: "type for reward data"
                    }
                    
                expose :is_process,
                    documentation: {
                        type: String,
                        desc: "is_process for reward data"
                    }
                expose :created_at,
                    documentation: {
                        type: String,
                        desc: "time earning reward referral"
                    }
            end
        end
    end
end