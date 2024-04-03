class CurrenciesWallet < ActiveRecord::Migration[5.2]
  def change
    create_table "currencies_wallets", id: false, force: :cascade do |t|
      t.bigint "currency_id"
      t.bigint "wallet_id"
      t.index ["currency_id", "wallet_id"], name: "index_currencies_wallets_on_currency_id_and_wallet_id", unique: true
      t.index ["currency_id"], name: "index_currencies_wallets_on_currency_id"
      t.index ["wallet_id"], name: "index_currencies_wallets_on_wallet_id"
    end
  end
end
