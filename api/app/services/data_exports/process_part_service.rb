# frozen_string_literal: true

module DataExports
  class ProcessPartService < BaseService
    Result = BaseResult[:data_export_part]

    def initialize(data_export_part:)
      @data_export_part = data_export_part
      @data_export = data_export_part.data_export
      super(nil)
    end

    def call
      result.data_export_part = data_export_part
      return result if data_export_part.completed

      # produce CSV lines into StringIO
      export_result = data_export.export_class.call(data_export_part:).raise_if_error!
      file = export_result.csv_file
      data_export_part.update!(csv_lines: file.read, completed: true)
      # Explicitly close and unlink the file
      file.close
      File.unlink(file.path)

      # check if we are the last one to finish
      if last_completed
        after_commit { DataExports::CombinePartsJob.perform_later(data_export_part.data_export) }
      end
      result
    end

    private

    attr_reader :data_export_part, :data_export

    def last_completed
      data_export.data_export_parts.completed.count == data_export.data_export_parts.count
    end
  end
end
