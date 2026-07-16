# frozen_string_literal: true

module ApiKeys
  class DestroyService < BaseService
    Result = BaseResult[:api_key]

    def initialize(api_key, force: false)
      @api_key = api_key
      @force = force
      super(api_key)
    end

    def call
      return result.not_found_failure!(resource: "api_key") unless api_key

      unless force || api_key.organization.api_keys.non_expiring.without(api_key).exists?
        return result.single_validation_failure!(error_code: "last_non_expiring_api_key")
      end

      api_key.touch(:expires_at) # rubocop:disable Rails/SkipsModelValidations

      ApiKeyMailer.with(api_key:).destroyed.deliver_later unless force
      ApiKeys::CacheService.expire_cache(api_key.value)

      register_security_log

      result.api_key = api_key
      result
    end

    private

    attr_reader :api_key, :force

    def register_security_log
      Utils::SecurityLog.produce(
        organization: api_key.organization,
        log_type: "api_key",
        log_event: "api_key.deleted",
        resources: {
          name: api_key.name,
          value_ending: api_key.value.last(4)
        }
      )
    end
  end
end
