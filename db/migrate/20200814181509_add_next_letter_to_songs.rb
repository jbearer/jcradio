class AddNextLetterToSongs < ActiveRecord::Migration
  def change
    add_column :songs, :next_letter, :string
  end
end
