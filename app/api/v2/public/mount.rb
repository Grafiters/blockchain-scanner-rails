# frozen_string_literal: true

module API
  module V2
    module Public
      class Mount < Grape::API

        before { set_ets_context! }

        mount Public::Currencies
        mount Public::Tools
        mount Public::Webhooks
        mount Public::Config
      end
    end
  end
end
