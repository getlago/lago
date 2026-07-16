# frozen_string_literal: true

module Organizations
  class UpdateService < BaseService
    Result = BaseResult[:organization]

    def initialize(organization:, params:, user: nil)
      @organization = organization
      @params = params
      @user = user

      super(nil)
    end

    def call
      organization.email = params[:email] if params.key?(:email)
      organization.legal_name = params[:legal_name] if params.key?(:legal_name)
      organization.legal_number = params[:legal_number] if params.key?(:legal_number)
      if params.key?(:tax_identification_number)
        organization.tax_identification_number = params[:tax_identification_number]
      end
      organization.address_line1 = params[:address_line1] if params.key?(:address_line1)
      organization.address_line2 = params[:address_line2] if params.key?(:address_line2)
      organization.zipcode = params[:zipcode] if params.key?(:zipcode)
      organization.city = params[:city] if params.key?(:city)
      organization.state = params[:state] if params.key?(:state)
      organization.country = params[:country]&.upcase if params.key?(:country)
      organization.default_currency = params[:default_currency]&.upcase if params.key?(:default_currency)
      organization.document_number_prefix = params[:document_number_prefix] if params.key?(:document_number_prefix)
      organization.slug = params[:slug]&.strip&.downcase if params.key?(:slug)
      organization.finalize_zero_amount_invoice = params[:finalize_zero_amount_invoice] if params.key?(:finalize_zero_amount_invoice)
      organization.net_payment_term = params[:net_payment_term] if params.key?(:net_payment_term)
      organization.document_numbering = params[:document_numbering] if params.key?(:document_numbering)
      if params.key?(:authentication_methods)
        deletions = organization.authentication_methods - params[:authentication_methods]
        additions = params[:authentication_methods] - organization.authentication_methods
        organization.authentication_methods = params[:authentication_methods]

        if organization.authentication_methods_changed? && user
          after_commit do
            OrganizationMailer.with(
              organization:,
              user:,
              additions:,
              deletions:
            ).authentication_methods_updated.deliver_later
          end
        end
      end

      billing = params[:billing_configuration]&.to_h || {}
      organization.invoice_footer = billing[:invoice_footer] if billing.key?(:invoice_footer)
      organization.document_locale = billing[:document_locale] if billing.key?(:document_locale)

      ActiveRecord::Base.transaction do
        handle_eu_tax_management(params[:eu_tax_management]) if params.key?(:eu_tax_management)

        if params.key?(:webhook_url)
          webhook_endpoint = organization.webhook_endpoints.first_or_initialize
          webhook_endpoint.update!(webhook_url: params[:webhook_url])
        end

        # TODO: only updates the organization grace period,
        #       it does not update related invoices payment due date, etc
        #       this is handled at the billing_entity level.
        #       Remove it when fully migrated to billing_entity.
        if License.premium? && billing.key?(:invoice_grace_period)
          organization.invoice_grace_period = billing[:invoice_grace_period]
        end

        assign_premium_attributes
        handle_base64_logo if params.key?(:logo)

        organization.save!
        update_billing_entity_result =
          BillingEntities::UpdateService.call(billing_entity: organization.default_billing_entity, params: params)
        update_billing_entity_result.raise_if_error!
      end

      ApiKeys::CacheService.expire_all_cache(organization)

      result.organization = organization
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue BaseService::FailedResult => e
      result.fail_with_error!(e)
    end

    private

    attr_reader :organization, :params, :user

    def assign_premium_attributes
      return unless License.premium?

      organization.timezone = params[:timezone] if params.key?(:timezone)
      organization.email_settings = params[:email_settings] if params.key?(:email_settings)
    end

    def handle_base64_logo
      return if params[:logo].blank?

      base64_data = params[:logo].split(",")
      data = base64_data.second
      decoded_base_64_data = Base64.decode64(data)

      # NOTE: data:image/png;base64, should give image/png content_type
      content_type = base64_data.first.split(";").first.split(":").second

      organization.logo.attach(
        io: StringIO.new(decoded_base_64_data),
        filename: "logo",
        content_type:
      )
    end

    def handle_eu_tax_management(eu_tax_management)
      # Note: Actual EU tax management is handled in the billing_entity update service
      organization.eu_tax_management = eu_tax_management

      return unless eu_tax_management

      unless organization.eu_vat_eligible?
        result.single_validation_failure!(error_code: "org_must_be_in_eu", field: :eu_tax_management)
          .raise_if_error!
      end
    end
  end
end
