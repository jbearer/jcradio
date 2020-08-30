class AddLastPlayedToSongs < ActiveRecord::Migration
  def change
    add_column :songs, :last_played, :integer, limit: 8
  end
end
