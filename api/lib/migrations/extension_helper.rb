# frozen_string_literal: true

module Migrations
  module ExtensionHelper
    def pg_extension_present?(extension)
      result = execute <<~SQL
        SELECT 1 FROM pg_available_extensions WHERE name = '#{extension}'
      SQL

      result.ntuples.positive?
    end
  end
end
