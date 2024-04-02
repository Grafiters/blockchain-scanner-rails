class Currencies < ActiveRecord::Migration[5.2]
  def change
    create_table "currencies", force: :cascade do |t|
      t.string "name"
      t.text "description"
      t.string "homepage"
      t.string "type", limit: 30, default: "coin", null: false
      t.string "status", limit: 32, default: "enabled", null: false
      t.integer "position", null: false
      t.integer "precision", limit: 1, default: 8, null: false
      t.string "icon_url"
      t.decimal "price", precision: 32, scale: 16, default: "1.0", null: false
      t.text "detail_currencies"
      t.decimal "market_cap", precision: 32, scale: 16, default: "0.0"
      t.integer "total_supply", default: 0
      t.integer "circulation_supply", default: 0
      t.json "options"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["position"], name: "index_currencies_on_position"
    end
  end
end
