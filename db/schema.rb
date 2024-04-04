# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2024_04_03_034906) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.decimal "min_deposit_amount", precision: 32, scale: 16, default: "0.0", null: false
    t.decimal "withdraw_fee", precision: 32, scale: 16, default: "0.0", null: false
    t.decimal "min_withdraw_amount", precision: 32, scale: 16, default: "0.0", null: false
    t.string "status", null: false
    t.integer "blockchain_group", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_blockchains_on_key", unique: true
    t.index ["status"], name: "index_blockchains_on_status"
  end

  create_table "currencies", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.string "type", limit: 30, default: "coin", null: false
    t.string "status", limit: 32, default: "enabled", null: false
    t.integer "position", null: false
    t.integer "precision", limit: 2, default: 8, null: false
    t.string "icon_url"
    t.json "options"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_currencies_on_code"
    t.index ["position"], name: "index_currencies_on_position"
  end

  create_table "currencies_wallets", id: false, force: :cascade do |t|
    t.bigint "currency_id"
    t.bigint "wallet_id"
    t.index ["currency_id", "wallet_id"], name: "index_currencies_wallets_on_currency_id_and_wallet_id", unique: true
    t.index ["currency_id"], name: "index_currencies_wallets_on_currency_id"
    t.index ["wallet_id"], name: "index_currencies_wallets_on_wallet_id"
  end

  create_table "deposits", force: :cascade do |t|
    t.string "blockchain_key", limit: 32
    t.string "member_id", null: false
    t.string "currency_id", limit: 10, null: false
    t.decimal "amount", precision: 32, scale: 16, null: false
    t.decimal "fee", precision: 32, scale: 16, null: false
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

  create_table "payment_addresses", force: :cascade do |t|
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

  create_table "withdraws", force: :cascade do |t|
    t.string "blockchain_key", limit: 32
    t.string "member_id", null: false
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
