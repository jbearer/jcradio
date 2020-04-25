class AddSelectorToSongsStations < ActiveRecord::Migration
  def change
    add_reference :songs_stations, :selector, index: true, foreign_key: true
  end
end
