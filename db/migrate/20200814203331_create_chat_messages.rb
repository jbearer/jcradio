class CreateChatMessages < ActiveRecord::Migration
  def change
    create_table :chat_messages do |t|
      t.text :message
      t.belongs_to :sender
      t.timestamps null: false
    end
  end
end
