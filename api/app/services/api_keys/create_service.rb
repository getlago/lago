# frozen_string_literal: true

module ApiKeys
  class CreateService < BaseService
    Result = BaseResult[:api_key]

    def initialize(params)
      @params = params
      super
    end

    def call
      return result.forbidden_failure! unless License.premium?

      if params[:permissions].present? && !params[:organization].api_permissions_enabled?
        return result.forbidden_failure!(code: "premium_integration_missing")
      end

      api_key = ApiKey.create!(
        params.slice(:organization, :name, :permissions)
      )

      ApiKeyMailer.with(api_key:).created.deliver_later

      register_security_log(api_key)

      result.api_key = api_key
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :params

    def register_security_log(api_key)
      Utils::SecurityLog.produce(
        organization: api_key.organization,
        log_type: "api_key",
        log_event: "api_key.created",
        resources: {
          name: api_key.name,
          value_ending: api_key.value.last(4),
          permissions: api_key.flat_permissions
        }
      )
    end
  end
end
