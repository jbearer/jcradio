class CreateNotifications < ActiveRecord::Migration
  def change
    create_table :notifications do |t|
      t.belongs_to :user
      t.text :text

      t.timestamps null: false
    end
  end
end
