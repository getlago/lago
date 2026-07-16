# frozen_string_literal: true

module DataExports
  class CombinePartsService < BaseService
    Result = BaseResult[:data_export]

    def initialize(data_export:)
      @data_export = data_export
      super
    end

    def call
      result.data_export = data_export
      ordered_parts = data_export.data_export_parts.order(index: :asc)

      Tempfile.create([data_export.resource_type, ".#{data_export.format}"]) do |tempfile|
        export_service = data_export.export_class.new(data_export_part: ordered_parts.first)
        tempfile.write(export_service.headers.join(","))
        tempfile.write("\n")

        # Note the order here, this is crucial to make sure the data is in the expected order
        ids = ordered_parts.ids
        # This is not the most optimal and will do N+1 queries, but the whole point is to not load the entire CSV in memory
        # we're trading speed for reliability here.
        ids.each do |id|
          tempfile.write(data_export.data_export_parts.find(id).csv_lines)
        end

        tempfile.rewind

        data_export.file.attach(
          io: tempfile,
          filename: data_export.filename,
          key: "data_exports/#{data_export.id}-#{SecureRandom.hex(5)}.#{data_export.format}",
          content_type: "text/csv"
        )
      end

      data_export.completed!
      DataExportMailer.with(data_export:).completed.deliver_later

      result
    end

    private

    attr_reader :data_export
  end
end
