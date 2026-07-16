# frozen_string_literal: true

module DataExports
  class CombinePartsJob < ApplicationJob
    queue_as :default

    unique :until_executed, on_conflict: :log

    def perform(data_export)
      CombinePartsService.call(data_export:).raise_if_error!
    end
  end
end
