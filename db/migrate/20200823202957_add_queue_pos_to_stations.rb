class AddQueuePosToStations < ActiveRecord::Migration
  def change
    add_column :stations, :queue_pos, :int
  end
end
