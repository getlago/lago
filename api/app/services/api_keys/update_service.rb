# frozen_string_literal: true

module ApiKeys
  class UpdateService < BaseService
    Result = BaseResult[:api_key]

    def initialize(api_key:, params:)
      @api_key = api_key
      @params = params
      super
    end

    def call
      return result.not_found_failure!(resource: "api_key") unless api_key

      if params[:permissions].present? && !api_key.organization.api_permissions_enabled?
        return result.forbidden_failure!(code: "premium_integration_missing")
      end

      old_flat_permissions = api_key.flat_permissions
      api_key.update!(params.slice(:name, :permissions))
      ApiKeys::CacheService.expire_cache(api_key.value)

      register_security_log(old_flat_permissions)

      result.api_key = api_key
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :api_key, :params

    def register_security_log(old_flat_permissions)
      diff = {}

      if api_key.previous_changes.key?("name")
        old_val, new_val = api_key.previous_changes["name"]
        diff[:name] = {deleted: old_val, added: new_val}.compact_blank
      end

      if api_key.previous_changes.key?("permissions")
        new_flat = api_key.flat_permissions
        entry = {}
        deleted = old_flat_permissions - new_flat
        added = new_flat - old_flat_permissions
        entry[:deleted] = deleted if deleted.present?
        entry[:added] = added if added.present?
        diff[:permissions] = entry if entry.present?
      end

      Utils::SecurityLog.produce(
        organization: api_key.organization,
        log_type: "api_key",
        log_event: "api_key.updated",
        resources: {
          name: api_key.name,
          value_ending: api_key.value.last(4),
          **diff
        }
      )
    end
  end
end
