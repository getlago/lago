# frozen_string_literal: true

namespace :lago do
  desc "Print the current version of Lago"
  task version: :environment do
    output = {
      number: LAGO_VERSION.number,
      github_url: LAGO_VERSION.github_url,
      schema_version: ApplicationRecord.connection.migration_context.current_version
    }

    if ENV["LAGO_CLICKHOUSE_MIGRATIONS_ENABLED"] == "true"
      output[:clickhouse_schema_version] = Clickhouse::BaseRecord.connection.migration_context.current_version
    end

    puts(output.to_json)
  end
end
