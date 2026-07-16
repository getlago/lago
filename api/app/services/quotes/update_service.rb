# frozen_string_literal: true

module Quotes
  class UpdateService < BaseService
    include OrderForms::Premium

    attr_reader :quote, :params, :owners

    Result = BaseResult[:quote]

    def initialize(quote:, params:)
      @quote = quote
      @params = params
      @owners = normalize_owners(owners: params[:owners])
      super
    end

    def call
      return result.not_found_failure!(resource: "quote") unless quote
      return result.forbidden_failure! unless order_forms_enabled?(quote.organization)
      return result.single_validation_failure!(field: :owners, error_code: "invalid") unless valid_owners?

      sync_owners!(quote:) if params.has_key?(:owners)

      # TODO: SendWebhookJob.perform_after_commit("quote.updated", quote)

      result.quote = quote.reload
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    def valid_owners?
      return true if owners.blank?

      known = quote.organization.memberships.active.where(user_id: owners).pluck(:user_id)
      (owners - known).empty?
    end

    def normalize_owners(owners:)
      return [] if owners.blank?
      return owners.map(&:to_s).uniq if owners.is_a?(Array)

      [owners.to_s]
    end

    def sync_owners!(quote:)
      QuoteOwner.transaction do
        current_owners = quote.owner_ids

        owners_to_remove = current_owners - owners
        quote.quote_owners.where(user_id: owners_to_remove).delete_all if owners_to_remove.any?

        owners_to_add = owners - current_owners
        owners_to_add.each do |user_id|
          quote.quote_owners.create!(
            organization_id: quote.organization_id,
            user_id: user_id
          )
        end
      end
    end
  end
end
