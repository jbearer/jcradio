class AddRadioStateToStations < ActiveRecord::Migration
  def change
    # State that previously lived in process globals and was lost on every restart.
    add_column :stations, :next_letter, :string
    add_column :stations, :buddy_taste, :text
    add_column :stations, :buddy_max_songs, :integer, default: 3
  end
end
