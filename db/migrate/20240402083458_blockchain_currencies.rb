class BlockchainCurrencies < ActiveRecord::Migration[5.2]
  def change
    create_table "blockchain_currencies", force: :cascade do |t|
      t.string "currency_id", null: false
      t.string "blockchain_key"
      t.string "parent_id"
      t.decimal "deposit_fee", precision: 32, scale: 16, default: "0.0", null: false
      t.decimal "min_deposit_amount", precision: 32, scale: 16, default: "0.0", null: false
      t.decimal "min_collection_amount", precision: 32, scale: 16, default: "0.0", null: false
      t.decimal "withdraw_fee", precision: 32, scale: 16, default: "0.0", null: false
      t.decimal "min_withdraw_amount", precision: 32, scale: 16, default: "0.0", null: false
      t.boolean "deposit_enabled", default: true, null: false
      t.boolean "withdrawal_enabled", default: true, null: false
      t.boolean "auto_update_fees_enabled", default: true, null: false
      t.bigint "base_factor", default: 1, null: false
      t.string "status", limit: 32, default: "enabled", null: false
      t.json "options"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["parent_id"], name: "index_blockchain_currencies_on_parent_id"
    end
  end
end
