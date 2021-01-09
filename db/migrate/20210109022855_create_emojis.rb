class CreateEmojis < ActiveRecord::Migration
  def change
    create_table :emojis do |t|
      t.string :name, unique: true
      t.string :content_type
      t.binary :data

      t.timestamps null: false
    end
  end
end
