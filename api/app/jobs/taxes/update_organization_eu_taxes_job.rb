# frozen_string_literal: true

module Taxes
  class UpdateOrganizationEuTaxesJob < ApplicationJob
    queue_as "default"

    def perform(organization)
      Taxes::AutoGenerateService.call!(organization:)
    end
  end
end
