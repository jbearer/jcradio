class AddNowPlayingToStations < ActiveRecord::Migration
  def change
    add_reference :stations, :now_playing, index: true, foreign_key: true
    add_reference :users, :station, index: true, foreign_key: true
  end
end
