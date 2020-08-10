class AddFirstLetterToSongs < ActiveRecord::Migration
  def change
    add_column :songs, :first_letter, :string
  end
end
