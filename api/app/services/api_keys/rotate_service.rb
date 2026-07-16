# frozen_string_literal: true

module ApiKeys
  class RotateService < BaseService
    Result = BaseResult[:api_key]

    def initialize(api_key:, params:)
      @api_key = api_key
      @params = params
      super
    end

    def call
      return result.not_found_failure!(resource: "api_key") unless api_key

      if params[:expires_at].present? && !License.premium?
        return result.forbidden_failure!(code: "cannot_rotate_with_provided_date")
      end

      expires_at = params[:expires_at] || Time.current
      new_api_key = api_key.organization.api_keys.new(name: params[:name])

      ActiveRecord::Base.transaction do
        new_api_key.save!
        api_key.update!(expires_at:)
      end

      ApiKeys::CacheService.expire_cache(api_key.value)
      ApiKeyMailer.with(api_key:).rotated.deliver_later

      register_security_log(new_api_key)

      result.api_key = new_api_key
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :api_key, :params

    def register_security_log(new_api_key)
      Utils::SecurityLog.produce(
        organization: new_api_key.organization,
        log_type: "api_key",
        log_event: "api_key.rotated",
        resources: {
          name: new_api_key.name,
          value_ending: {deleted: api_key.value.last(4), added: new_api_key.value.last(4)}.compact
        }
      )
    end
  end
end
