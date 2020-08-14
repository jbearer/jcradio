class CreateUpvotes < ActiveRecord::Migration
  def change
    rename_table :songs_stations, :queue_entries

    create_table :upvotes do |t|
        t.belongs_to :queue_entry
        t.belongs_to :upvoter
        t.timestamps null: false
    end
  end
end
