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

ActiveRecord::Schema[7.1].define(version: 2026_08_28_204526) do
  create_table "articles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "care_subjects", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "nickname"
    t.integer "birth_year"
    t.string "relationship"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_care_subjects_on_user_id", unique: true
  end

  create_table "check_records", force: :cascade do |t|
    t.integer "care_subject_id", null: false
    t.date "recorded_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "checked_ids"
    t.text "scores"
    t.string "top_type"
    t.integer "total_checked", default: 0, null: false
    t.string "lang", default: "ja", null: false
    t.index ["care_subject_id", "recorded_on"], name: "index_check_records_on_care_subject_id_and_recorded_on"
    t.index ["care_subject_id"], name: "index_check_records_on_care_subject_id"
  end

  create_table "daily_logs", force: :cascade do |t|
    t.integer "care_subject_id", null: false
    t.date "logged_on", null: false
    t.integer "meal", default: 1, null: false
    t.integer "sleep", default: 1, null: false
    t.integer "mood", default: 2, null: false
    t.text "memo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["care_subject_id", "logged_on"], name: "index_daily_logs_on_care_subject_id_and_logged_on", unique: true
    t.index ["care_subject_id"], name: "index_daily_logs_on_care_subject_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "provider"
    t.string "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "patient_name"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "care_subjects", "users"
  add_foreign_key "check_records", "care_subjects"
  add_foreign_key "daily_logs", "care_subjects"
end
