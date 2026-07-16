# frozen_string_literal: true

module DataApi
  class PrepaidCreditsService < DataApi::BaseService
    Result = BaseResult[:prepaid_credits]

    def call
      return result.forbidden_failure! unless License.premium?

      result.prepaid_credits = http_client.get(headers:, params:)
      result
    end

    private

    def action_path
      "prepaid_credits/#{organization.id}/"
    end
  end
end
