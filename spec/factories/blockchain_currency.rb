# frozen_string_literal: true

FactoryBot.define do
  factory :blockchain_currency do
		trait :usd_network do
			currency_code          { 'usd' }
      withdraw_fee         { 0.1 }
			status               { 'enabled' }
      options              { {} }
		end

		trait :eur_network do
			currency_code          { 'eur' }
      withdraw_fee         { 0.1 }
      status               { 'disabled' }
      options              { {} }
    end

    trait :btc_network do
      currency_code          { 'btc' }
      blockchain_key       { 'btc-testnet' }
      base_factor          { 100_000_000 }
      withdraw_fee         { 0.01 }
      options              { {} }
    end

    trait :eth_network do
			currency_code          { 'eth' }
      blockchain_key       { 'eth-rinkeby' }
      base_factor          { 1_000_000_000_000_000_000 }
      withdraw_fee         { 0.025 }
      options do
        { gas_limit: 21_000 }
      end
    end

    trait :trst_network do
			currency_code          { 'trst' }
      parent_id            { 'eth' }
      blockchain_key       { 'eth-rinkeby' }
      base_factor          { 1_000_000 }
      withdraw_fee         { 0.025 }
      options do
        { gas_limit: 90_000,
          erc20_contract_address: '0x87099adD3bCC0821B5b151307c147215F839a110' }
      end
    end

    trait :tom_network do
			currency_code          { 'tom' }
      parent_id            { 'eth' }
      blockchain_key       { 'eth-rinkeby' }
      base_factor          { 1_000_000 }
      withdraw_fee         { 0.025 }
      options do
        { gas_limit: 90_000,
          erc20_contract_address: '0xf7970499814654cd13cb7b6e7634a12a7a8a9abc' }
      end
    end

    trait :ring_network do
			currency_code          { 'ring' }
      parent_id            { 'eth' }
      blockchain_key       { 'eth-kovan' }
      base_factor          { 1_000_000 }
      withdraw_fee         { 0.025 }
      options \
        { { erc20_contract_address: '0xf8720eb6ad4a530cccb696043a0d10831e2ff60e' } }
    end

    trait :fake_network do
      blockchain_key      { 'fake-testnet' }
      currency_code         { 'fake' }
      base_factor         { 1_000_000 }
      withdraw_fee        { 0.02 }
      options             { {} }
    end

    trait :xagm_cx_network do
      blockchain_key      { 'eth-rinkeby' }
      parent_id           { 'eth' }
      currency_code         { 'xagm.cx' }
      base_factor         { 1_000_000 }
      withdraw_fee        { 0.02 }
      options             { {} }
    end
	end
end
