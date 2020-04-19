class AddPositionToSongsStations < ActiveRecord::Migration
  def change
    add_column :songs_stations, :position, :integer
    add_index :songs_stations, :position
  end
end
