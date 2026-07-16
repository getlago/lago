# frozen_string_literal: true

module DunningCampaigns
  class UpdateService < BaseService
    Result = BaseResult[:dunning_campaign]

    def initialize(organization:, dunning_campaign:, params:)
      @dunning_campaign = dunning_campaign
      @organization = organization
      @default_billing_entity = organization.default_billing_entity
      @params = params

      super
    end

    def call
      return result.forbidden_failure! unless organization.auto_dunning_enabled?
      return result.not_found_failure!(resource: "dunning_campaign") unless dunning_campaign

      ActiveRecord::Base.transaction do
        dunning_campaign.assign_attributes(permitted_attributes)
        handle_thresholds if params.key?(:thresholds)
        # TODO: remove this when FE is released and we handle applied on billing entity
        handle_applied_to_organization_update if params.key?(:applied_to_organization)

        dunning_campaign.save!
      end

      result.dunning_campaign = dunning_campaign
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :dunning_campaign, :organization, :params, :default_billing_entity

    def permitted_attributes
      params.slice(:name, :bcc_emails, :code, :description, :days_between_attempts, :max_attempts)
    end

    def handle_thresholds
      input_threshold_ids = params[:thresholds].map { |t| t[:id] }.compact

      # Delete thresholds not included in the payload
      discarded_thresholds = dunning_campaign # rubocop:disable Lago/DiscardAll
        .thresholds
        .where.not(id: input_threshold_ids)
        .discard_all

      thresholds_updated = discarded_thresholds.present?

      # Update or create new thresholds from the input
      params[:thresholds].each do |threshold_input|
        threshold = dunning_campaign.thresholds
          .find_or_initialize_by(id: threshold_input[:id]) { |t| t.organization_id = organization.id }

        threshold.assign_attributes(threshold_input.to_h.slice(:amount_cents, :currency))

        thresholds_updated ||= threshold.changed? && threshold.persisted?
        threshold.save!
      end

      reset_customers_if_no_threshold_match if thresholds_updated
    end

    def reset_customers_if_no_threshold_match
      customers_to_reset
        .includes(:invoices)
        .where(invoices: {payment_overdue: true}).find_each do |customer|
          balances = customer.overdue_balances
          threshold_matches = dunning_campaign.thresholds.any? do |threshold|
            (balances[threshold.currency] || 0) >= threshold.amount_cents
          end

          unless threshold_matches
            customer.update!(
              dunning_currency_attempts: {},
              last_dunning_campaign_attempt: 0,
              last_dunning_campaign_attempt_at: nil
            )
          end
        end
    end

    def customers_to_reset
      @customers_to_reset ||= customers_applied_campaign.or(customers_fallback_campaign)
    end

    def customers_applied_campaign
      organization.customers.where(applied_dunning_campaign: dunning_campaign)
    end

    def customers_fallback_campaign
      organization.customers.falling_back_to_default_dunning_campaign.where(billing_entity_id: dunning_campaign.billing_entities.ids)
    end

    def handle_applied_to_organization_update
      new_dunning_campaign_id = params[:applied_to_organization] ? dunning_campaign.id : nil
      return if default_billing_entity.applied_dunning_campaign_id == new_dunning_campaign_id

      default_billing_entity.update!(applied_dunning_campaign_id: new_dunning_campaign_id)
      default_billing_entity.reset_customers_last_dunning_campaign_attempt
    end
  end
end
