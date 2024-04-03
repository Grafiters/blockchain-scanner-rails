class Transactions < ActiveRecord::Migration[5.2]
  def change
    create_table "transactions", force: :cascade do |t|
    t.string "currency_id", null: false
    t.string "reference_type"
    t.bigint "reference_id"
    t.string "txid"
    t.string "from_address"
    t.string "to_address"
    t.decimal "amount", precision: 32, scale: 16, default: "0.0", null: false
    t.integer "block_number"
    t.integer "txout"
    t.string "status"
    t.json "options"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_id", "txid"], name: "index_transactions_on_currency_id_and_txid", unique: true
    t.index ["currency_id"], name: "index_transactions_on_currency_id"
    t.index ["reference_type", "reference_id"], name: "index_transactions_on_reference_type_and_reference_id"
    t.index ["txid"], name: "index_transactions_on_txid"
  end
  end
end
