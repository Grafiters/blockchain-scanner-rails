class Withdraws < ActiveRecord::Migration[5.2]
  def change
    create_table "withdraws", force: :cascade do |t|
      t.string "blockchain_key", limit: 32
      t.string "member_id", null: false
      t.bigint "beneficiary_id"
      t.string "currency_id", limit: 10, null: false
      t.decimal "amount", precision: 32, scale: 16, null: false
      t.decimal "fee", precision: 32, scale: 16, null: false
      t.string "txid", limit: 128
      t.string "aasm_state", limit: 30, null: false
      t.integer "block_number"
      t.decimal "sum", precision: 32, scale: 16, null: false
      t.string "type", limit: 30, null: false
      t.integer "transfer_type"
      t.string "tid", limit: 64, null: false
      t.string "rid", limit: 256, null: false
      t.string "remote_id"
      t.string "note", limit: 256
      t.json "metadata"
      t.json "error"
      t.datetime "created_at", precision: 3, null: false
      t.datetime "updated_at", precision: 3, null: false
      t.datetime "completed_at", precision: 3
      t.index ["aasm_state"], name: "index_withdraws_on_aasm_state"
      t.index ["currency_id", "txid"], name: "index_withdraws_on_currency_id_and_txid", unique: true
      t.index ["currency_id"], name: "index_withdraws_on_currency_id"
      t.index ["member_id"], name: "index_withdraws_on_member_id"
      t.index ["tid"], name: "index_withdraws_on_tid"
      t.index ["type"], name: "index_withdraws_on_type"
    end
  end
end
