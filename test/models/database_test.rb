require 'test_helper'

class DatabaseTest < ActiveSupport::TestCase
  test "sqlite connections use write-ahead logging" do
    assert_equal 'wal', ActiveRecord::Base.connection.select_value('PRAGMA journal_mode')
  end
end
