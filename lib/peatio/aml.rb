# frozen_string_literal: true

module Peatio
  module AML
    class << self
      attr_accessor :adapter

      def check!(address, currency_code, uid)
        adapter.check!(address, currency_code, uid)
      end
    end

    class Abstract
      def check!(_address, _currency_code, _uid)
        method_not_implemented
      end
    end
  end
end
