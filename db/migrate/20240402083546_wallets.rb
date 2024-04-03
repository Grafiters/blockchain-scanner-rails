class Wallets < ActiveRecord::Migration[5.2]
  def change
    create_table "wallets", force: :cascade do |t|
      t.string "blockchain_key", limit: 32
      t.string "name", limit: 64
      t.string "address", null: false
      t.integer "kind", null: false
      t.string "gateway", limit: 20, default: "", null: false
      t.json "plain_settings"
      t.json "settings"
      t.json "balance"
      t.decimal "max_balance", precision: 32, scale: 16, default: "0.0", null: false
      t.string "status", limit: 32
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["kind", "status"], name: "index_wallets_on_kind_and_currency_id_and_status"
      t.index ["kind"], name: "index_wallets_on_kind"
      t.index ["status"], name: "index_wallets_on_status"
    end
  end
end
