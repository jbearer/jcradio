class CreateVapidTable < ActiveRecord::Migration
  def change
    create_table :vapid do |t|
        t.string :public_key
        t.string :private_key
    end
  end
end
