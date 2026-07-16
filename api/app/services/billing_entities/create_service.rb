# frozen_string_literal: true

module BillingEntities
  class CreateService < BaseService
    Result = BaseResult[:billing_entity]

    def initialize(organization:, params:)
      @organization = organization
      @params = params
      @billing_entity = organization.billing_entities.new
      super
    end

    activity_loggable(
      action: "billing_entities.created",
      record: -> { result.billing_entity }
    )

    def call
      return result.forbidden_failure! unless organization.can_create_billing_entity?

      ActiveRecord::Base.transaction do
        billing_entity.assign_attributes(create_attributes)
        billing_entity.id = params[:id] if params[:id]
        billing_entity.invoice_footer = billing_config[:invoice_footer]
        billing_entity.document_locale = billing_config[:document_locale] if billing_config[:document_locale]
        billing_entity.einvoicing = params[:einvoicing] if params[:einvoicing]

        handle_eu_tax_management if params[:eu_tax_management]
        handle_base64_logo

        if License.premium?
          billing_entity.invoice_grace_period = billing_config[:invoice_grace_period] if billing_config[:invoice_grace_period]
          billing_entity.timezone = params[:timezone] if params[:timezone]
          billing_entity.email_settings = params[:email_settings] if params[:email_settings]
          billing_entity.subscription_invoice_issuing_date_anchor = billing_config[:subscription_invoice_issuing_date_anchor] if billing_config[:subscription_invoice_issuing_date_anchor]
          billing_entity.subscription_invoice_issuing_date_adjustment = billing_config[:subscription_invoice_issuing_date_adjustment] if billing_config[:subscription_invoice_issuing_date_adjustment]
        end

        billing_entity.save!
      end

      track_billing_entity_created
      register_security_log(billing_entity)

      result.billing_entity = billing_entity
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      result.fail_with_error!(e)
    end

    private

    attr_reader :organization, :params, :billing_entity

    def create_attributes
      @create_attributes ||= params.slice(
        *%I[
          address_line1
          address_line2
          city
          code
          country
          default_currency
          document_number_prefix
          document_numbering
          email
          finalize_zero_amount_invoice
          legal_name
          legal_number
          name
          net_payment_term
          phone
          state
          tax_identification_number
          vat_rate
          zipcode
        ]
      )
    end

    def billing_config
      @billing_config ||= params[:billing_configuration]&.to_h || {}
    end

    def handle_base64_logo
      return if params[:logo].blank?

      base64_data = params[:logo].split(",")
      data = base64_data.second
      decoded_base_64_data = Base64.decode64(data)

      # NOTE: data:image/png;base64, should give image/png content_type
      content_type = base64_data.first.split(";").first.split(":").second

      billing_entity.logo.attach(
        io: StringIO.new(decoded_base_64_data),
        filename: "logo",
        content_type:
      )
    end

    def handle_eu_tax_management
      ChangeEuTaxManagementService.call!(
        billing_entity:,
        eu_tax_management: params[:eu_tax_management]
      )
    end

    def register_security_log(billing_entity)
      Utils::SecurityLog.produce(
        organization:,
        log_type: "billing_entity",
        log_event: "billing_entity.created",
        resources: {billing_entity_name: billing_entity.name, billing_entity_code: billing_entity.code}
      )
    end

    def track_billing_entity_created
      SegmentTrackJob.perform_later(
        membership_id: CurrentContext.membership,
        event: "billing_entity_created",
        properties: {
          billing_entity_code: billing_entity.code,
          billing_entity_name: billing_entity.name,
          organization_id: billing_entity.organization_id
        }
      )
    end
  end
end
