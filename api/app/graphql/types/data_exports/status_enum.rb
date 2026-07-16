# frozen_string_literal: true

module Types
  module DataExports
    class StatusEnum < Types::BaseEnum
      graphql_name "DataExportStatusEnum"

      DataExport::STATUSES.each do |status|
        value status
      end
    end
  end
end
