class AddVersionToChatMessages < ActiveRecord::Migration
  def change
    add_column :chat_messages, :version, :number, default: 0
  end
end
