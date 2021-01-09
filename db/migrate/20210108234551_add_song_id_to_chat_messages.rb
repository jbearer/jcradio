class AddSongIdToChatMessages < ActiveRecord::Migration
  def change
    add_reference :chat_messages, :song, foreign_key: true
  end
end
