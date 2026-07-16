# frozen_string_literal: true

module DataApi
  class MrrsService < BaseService
    Result = BaseResult[:mrrs]

    def call
      return result.forbidden_failure! unless License.premium?

      data_mrrs = http_client.get(headers:, params:)

      result.mrrs = data_mrrs
      result
    end

    private

    def action_path
      "mrrs/#{organization.id}/"
    end
  end
end
