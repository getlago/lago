# frozen_string_literal: true

namespace :db do
  # NOTE: The main benefit is to avoid PG::ObjectInUse error when dropping
  #       Migration state is preserved so `db:migrate:redo:primary` can still be used
  desc "Truncate all tables and keep migrations state"
  task truncate: :environment do
    raise "Can only be used in development" unless Rails.env.development?

    ActiveRecord::Base.connection.tables.each do |table|
      next if table == "schema_migrations" || table == "ar_internal_metadata"
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE")
    end
  end
end
