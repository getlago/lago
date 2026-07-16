# frozen_string_literal: true

require "csv"
require "forwardable"

module DataExports
  module Csv
    class BaseCsvService < ::BaseService
      extend Forwardable

      def call
        result.csv_file = with_csv do |csv|
          collection.each do |item|
            serialize_item(item, csv)
          end
        end

        result
      end

      private

      def with_csv
        tempfile = Tempfile.create([data_export_part.id, ".csv"])
        yield CSV.new(tempfile, headers: false)

        tempfile.rewind
        tempfile
      end
    end
  end
end
