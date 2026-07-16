# frozen_string_literal: true

module DunningCampaigns
  class CreateService < BaseService
    Result = BaseResult[:dunning_campaign]

    def initialize(organization:, params:)
      @organization = organization
      @params = params

      super
    end

    def call
      return result.forbidden_failure! unless organization.auto_dunning_enabled?
      return result.validation_failure!(errors: {thresholds: ["can't be blank"]}) if params[:thresholds].blank?

      ActiveRecord::Base.transaction do
        if params[:applied_to_organization]
          organization.dunning_campaigns.applied_to_organization
            .update_all(applied_to_organization: false) # rubocop:disable Rails/SkipsModelValidations

          organization.default_billing_entity.reset_customers_last_dunning_campaign_attempt
        end

        dunning_campaign = organization.dunning_campaigns.create!(
          code: params[:code],
          bcc_emails: Array.wrap(params[:bcc_emails]),
          days_between_attempts: params[:days_between_attempts],
          max_attempts: params[:max_attempts],
          name: params[:name],
          description: params[:description],
          thresholds_attributes: params[:thresholds].map { it.to_h.merge(organization_id: organization.id) }
        )
        organization.default_billing_entity.update!(applied_dunning_campaign: dunning_campaign) if params[:applied_to_organization]

        result.dunning_campaign = dunning_campaign
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :organization, :params
  end
end
