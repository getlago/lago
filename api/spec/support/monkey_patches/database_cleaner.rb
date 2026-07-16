# frozen_string_literal: true

# Monkey patch database cleaner to be compatible with Clickhouse.
module DatabaseCleaner
  module ActiveRecord
    class Deletion
      def delete_table(connection, table_name)
        arel = Arel::DeleteManager.new.from(Arel::Table.new(table_name)).where(Arel.sql("1=1"))
        connection.delete(arel)
      end
    end
  end
end
