module API
    module V2
        module Entities
            class Setting < Base
                expose :name,
                    documentation: {
                        type: String,
                        desc: 'The name of setting configuration'
                    }

                expose :value,
                    documentation: {
                        type: String,
                        desc: 'The value of setting configuration'
                    }
                    
            end
        end
    end
end