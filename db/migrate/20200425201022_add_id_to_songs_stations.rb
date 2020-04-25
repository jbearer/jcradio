class AddIdToSongsStations < ActiveRecord::Migration
  def change
    add_column :songs_stations, :id, :primary_key
  end
end
