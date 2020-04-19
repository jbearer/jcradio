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

ActiveRecord::Schema.define(version: 20200419001711) do

  create_table "songs", force: :cascade do |t|
    t.string   "source"
    t.string   "source_id"
    t.string   "title"
    t.string   "artist"
    t.string   "album"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "songs_stations", id: false, force: :cascade do |t|
    t.integer "song_id"
    t.integer "station_id"
    t.integer "position"
  end

  add_index "songs_stations", ["position"], name: "index_songs_stations_on_position"

  create_table "stations", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.integer  "now_playing_id"
  end

  add_index "stations", ["now_playing_id"], name: "index_stations_on_now_playing_id"

  create_table "users", force: :cascade do |t|
    t.string   "username"
    t.integer  "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer  "station_id"
  end

  add_index "users", ["station_id"], name: "index_users_on_station_id"

end
