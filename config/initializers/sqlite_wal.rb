require 'active_record/connection_adapters/sqlite3_adapter'

# Rollback-journal SQLite makes COMMIT wait for every reader (library browse, SSE, worker);
# past 5.1s that surfaced as "database is locked" after the Spotify queue call had already
# succeeded. WAL lets readers and the single writer proceed independently. Persistent per file.
module SQLiteWriteAheadLog
  def initialize(*)
    super
    execute("PRAGMA journal_mode = WAL", "SCHEMA")
  end
end

ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SQLiteWriteAheadLog)
