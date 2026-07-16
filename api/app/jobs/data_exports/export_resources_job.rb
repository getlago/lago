# frozen_string_literal: true

module DataExports
  class ExportResourcesJob < ApplicationJob
    queue_as :default

    DEFAULT_BATCH_SIZE = 20

    def perform(data_export, batch_size: DEFAULT_BATCH_SIZE)
      ExportResourcesService.call(data_export:, batch_size:).raise_if_error!
    end
  end
end
