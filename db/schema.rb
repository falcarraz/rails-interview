# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_03_03_205459) do
  create_table "todo_list_items", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.boolean "completed", default: false
    t.integer "todo_list_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.datetime "synced_at"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_todo_list_items_on_deleted_at"
    t.index ["external_id"], name: "index_todo_list_items_on_external_id", unique: true
    t.index ["todo_list_id"], name: "index_todo_list_items_on_todo_list_id"
  end

  create_table "todo_lists", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.datetime "synced_at"
    t.index ["external_id"], name: "index_todo_lists_on_external_id", unique: true
  end

  add_foreign_key "todo_list_items", "todo_lists"
end
