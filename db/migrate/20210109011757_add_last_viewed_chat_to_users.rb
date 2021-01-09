class AddLastViewedChatToUsers < ActiveRecord::Migration
  def change
    add_column :users, :last_viewed_chat, :timestamps
  end
end
