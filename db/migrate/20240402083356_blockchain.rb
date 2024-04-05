class Blockchain < ActiveRecord::Migration[5.2]
  def change
    create_table "blockchains", force: :cascade do |t|
      t.string "key", null: false
      t.string "name"
      t.string "client", null: false
      t.string "server", limit: 1024
      t.bigint "height", null: false
      t.string "collection_gas_speed"
      t.string "withdrawal_gas_speed"
      t.text "description"
      t.text "warning"
      t.string "protocol", null: false
      t.string "explorer_address"
      t.string "explorer_transaction"
      t.integer "min_confirmations", default: 6, null: false
      t.decimal "min_deposit_amount", precision: 32, scale: 18, default: "0.0", null: false
      t.decimal "withdraw_fee", precision: 32, scale: 18, default: "0.0", null: false
      t.decimal "min_withdraw_amount", precision: 32, scale: 18, default: "0.0", null: false
      t.string "status", null: false
      t.integer "blockchain_group", default: 1, null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["key"], name: "index_blockchains_on_key", unique: true
      t.index ["status"], name: "index_blockchains_on_status"
    end  
  end
end