# frozen_string_literal: true

module Charges
  class CreateChildrenBatchJob < ApplicationJob
    queue_as "default"

    def perform(child_ids:, charge:, payload:)
      Charges::CreateChildrenService.call!(child_ids:, charge:, payload:)
    end
  end
end
