class AddNowPlayingStartMsToStation < ActiveRecord::Migration
  def change
    add_column :stations, :now_playing_start_ms, :integer, limit: 8
  end
end
