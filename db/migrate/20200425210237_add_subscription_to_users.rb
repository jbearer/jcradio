class AddSubscriptionToUsers < ActiveRecord::Migration
  def change
    add_column :users, :subscription, :text
  end
end
