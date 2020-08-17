class AddUrlToNotifications < ActiveRecord::Migration
  def change
    add_column :notifications, :url, :text
  end
end
