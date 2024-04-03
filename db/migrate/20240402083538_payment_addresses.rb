class PaymentAddresses < ActiveRecord::Migration[5.2]
  def change
    create_table "payment_addresses",force: :cascade do |t|
      t.string "blockchain_key", limit: 32
      t.bigint "member_id"
      t.bigint "wallet_id"
      t.string "address", limit: 95
      t.boolean "remote", default: false, null: false
      t.string "secret"
      t.string "details", limit: 1024
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["member_id"], name: "index_payment_addresses_on_member_id"
      t.index ["wallet_id"], name: "index_payment_addresses_on_wallet_id"
    end
  end
end
