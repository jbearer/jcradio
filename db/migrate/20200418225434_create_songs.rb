class CreateSongs < ActiveRecord::Migration
  def change
    create_table :songs do |t|
      t.string :source
      t.string :source_id

      t.string :title
      t.string :artist
      t.string :album

      t.timestamps null: false
    end

    create_table :songs_stations, id: false do |t|
        t.belongs_to :song
        t.belongs_to :station
    end
  end
end
