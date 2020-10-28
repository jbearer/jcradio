class AddWasRecommendedToQueueEntry < ActiveRecord::Migration
  def change
    add_column :queue_entries, :was_recommended, :boolean
  end
end
