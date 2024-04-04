class Currencies < ActiveRecord::Migration[5.2]
  def change
    create_table "currencies", force: :cascade do |t|
      t.string "code", index: true
      t.string "name"
      t.string "type", limit: 30, default: "coin", null: false
      t.string "status", limit: 32, default: "enabled", null: false
      t.integer "position", null: false
      t.integer "precision", limit: 1, default: 8, null: false
      t.string "icon_url"
      t.json "options"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false

      t.index ["position"], name: "index_currencies_on_position"
    end
  end
end
