class Deposits < ActiveRecord::Migration[5.2]
  def change
    create_table "deposits", force: :cascade do |t|
      t.string "blockchain_key", limit: 32
      t.string "member_id", null: false
      t.string "currency_id", limit: 10, null: false
      t.decimal "amount", precision: 32, scale: 18, null: false
      t.decimal "fee", precision: 32, scale: 18, null: false
      t.string "address", limit: 95
      t.text "from_addresses"
      t.string "txid", limit: 128
      t.integer "txout"
      t.string "aasm_state", limit: 30, null: false
      t.integer "block_number"
      t.string "type", limit: 30, null: false
      t.integer "transfer_type"
      t.string "tid", limit: 64, null: false
      t.string "spread", limit: 1000
      t.json "error"
      t.datetime "created_at", precision: 3, null: false
      t.datetime "updated_at", precision: 3, null: false
      t.datetime "completed_at", precision: 3
      t.index ["aasm_state", "member_id", "currency_id"], name: "index_deposits_on_aasm_state_and_member_id_and_currency_id"
      t.index ["currency_id", "txid", "txout"], name: "index_deposits_on_currency_id_and_txid_and_txout", unique: true
      t.index ["currency_id"], name: "index_deposits_on_currency_id"
      t.index ["member_id", "txid"], name: "index_deposits_on_member_id_and_txid"
      t.index ["tid"], name: "index_deposits_on_tid"
      t.index ["type"], name: "index_deposits_on_type"
    end
  end
end
