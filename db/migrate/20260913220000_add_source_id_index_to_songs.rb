class AddSourceIdIndexToSongs < ActiveRecord::Migration
  # Library browse matches hundreds of Spotify ids per request (Song.where(source_id: ...))
  # and Song.get looks songs up by source_id; both were full scans.
  def change
    add_index :songs, :source_id
  end
end
