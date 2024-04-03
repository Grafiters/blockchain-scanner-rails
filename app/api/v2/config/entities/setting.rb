module API
    module V2
        module Config
            module Entities
                class Setting < API::V2::Entities::Setting
                    expose :id,
                        documentation: {
                            type: Integer,
                            desc: 'The identifier of setting configuration'   
                        }          

                    expose :description,
                        documentation: {
                            type: String,
                            desc: 'The description of the setting'
                        }
                    expose :deleted,
                        documentation: {
                            type: String,
                            desc: 'The identifier of setting configuration is can deleted or not'
                        }

                    expose(
                        :created_at,
                        format_with: :iso8601,
                        documentation: {
                            type: String,
                            desc: 'setting created time in iso8601 format.'
                        }
                    )

                    expose(
                        :updated_at,
                        format_with: :iso8601,
                        documentation: {
                            type: String,
                            desc: 'setting updated time in iso8601 format.'
                        }
                    )
                end
            end
        end
    end
end