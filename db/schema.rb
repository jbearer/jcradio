# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20210420184241) do

  create_table "chat_messages", force: :cascade do |t|
    t.text     "message"
    t.integer  "sender_id"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.integer  "song_id"
    t.decimal  "version",    default: 0.0
  end

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "emojis", force: :cascade do |t|
    t.string   "name"
    t.string   "content_type"
    t.binary   "data"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "notifications", force: :cascade do |t|
    t.integer  "user_id"
    t.text     "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text     "url"
  end

  create_table "queue_entries", force: :cascade do |t|
    t.integer "song_id"
    t.integer "station_id"
    t.integer "position"
    t.integer "selector_id"
    t.boolean "was_recommended"
  end

  add_index "queue_entries", ["position"], name: "index_queue_entries_on_position"
  add_index "queue_entries", ["selector_id"], name: "index_queue_entries_on_selector_id"

  create_table "sessions", force: :cascade do |t|
    t.string   "session_id", null: false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", unique: true
  add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at"

  create_table "songs", force: :cascade do |t|
    t.string   "source"
    t.string   "source_id"
    t.string   "title"
    t.string   "artist"
    t.string   "album"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.integer  "duration"
    t.string   "uri"
    t.string   "first_letter"
    t.string   "next_letter"
    t.integer  "last_played",  limit: 8
    t.string   "preview_url"
  end

  create_table "stations", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.integer  "now_playing_id"
    t.integer  "queue_pos"
    t.integer  "now_playing_start_ms", limit: 8
  end

  add_index "stations", ["now_playing_id"], name: "index_stations_on_now_playing_id"

  create_table "trigrams", force: :cascade do |t|
    t.string  "trigram",     limit: 3
    t.integer "score",       limit: 2
    t.integer "owner_id"
    t.string  "owner_type"
    t.string  "fuzzy_field"
  end

  add_index "trigrams", ["owner_id", "owner_type", "fuzzy_field", "trigram", "score"], name: "index_for_match"
  add_index "trigrams", ["owner_id", "owner_type"], name: "index_by_owner"

  create_table "upvotes", force: :cascade do |t|
    t.integer "queue_entry_id"
    t.integer "upvoter_id"
  end

  create_table "users", force: :cascade do |t|
    t.string   "username"
    t.integer  "position"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.integer  "station_id"
    t.text     "subscription"
    t.datetime "last_viewed_chat"
  end

  add_index "users", ["station_id"], name: "index_users_on_station_id"

  create_table "vapid", force: :cascade do |t|
    t.string "public_key"
    t.string "private_key"
  end

end
