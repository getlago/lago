# frozen_string_literal: true

module Api
  module V1
    class InvoicesController < Api::BaseController
      include InvoiceIndex

      def create
        result = Invoices::CreateOneOffService.call(
          customer:,
          currency: create_params[:currency],
          fees: create_params[:fees],
          timestamp: Time.current.to_i,
          skip_psp: create_params[:skip_psp],
          invoice_custom_section: create_params[:invoice_custom_section] || {},
          payment_method_params: create_params[:payment_method],
          billing_entity_code: create_params[:billing_entity_code],
          purchase_order_number: create_params[:purchase_order_number]
        )

        if result.success?
          render_invoice(result.invoice)
        else
          render_error_response(result)
        end
      end

      def update
        invoice = current_organization.invoices.visible.find_by(id: params[:id])

        result = Invoices::UpdateService.new(
          invoice:,
          params: update_params.to_h.deep_symbolize_keys,
          webhook_notification: true
        ).call

        if result.success?
          render_invoice(result.invoice)
        else
          render_error_response(result)
        end
      end

      def show
        invoice = current_organization.invoices.visible.find_by(id: params[:id])

        return not_found_error(resource: "invoice") unless invoice

        render_invoice(invoice)
      end

      def index
        permitted_params = params.permit(:external_customer_id, :customer_external_id)
        customer_external_id = permitted_params[:external_customer_id] || permitted_params[:customer_external_id]
        invoice_index(customer_external_id: customer_external_id)
      end

      def download_pdf
        invoice = current_organization.invoices.finalized.find_by(id: params[:id])

        return not_found_error(resource: "invoice") unless invoice

        if invoice.file.present?
          return render(
            json: ::V1::InvoiceSerializer.new(
              invoice,
              root_name: "invoice"
            )
          )
        end

        Invoices::GeneratePdfJob.perform_later(invoice)

        head(:ok)
      end

      def download_xml
        invoice = current_organization.invoices.finalized.find_by(id: params[:id])

        return not_found_error(resource: "invoice") unless invoice

        if invoice.xml_file.present?
          return render(
            json: ::V1::InvoiceSerializer.new(
              invoice,
              root_name: "invoice"
            )
          )
        end

        Invoices::GenerateXmlJob.perform_later(invoice)

        head(:ok)
      end

      def refresh
        invoice = current_organization.invoices.visible.find_by(id: params[:id])
        return not_found_error(resource: "invoice") unless invoice

        result = Invoices::RefreshDraftService.call(invoice:)
        if result.success?
          render_invoice(result.invoice)
        else
          render_error_response(result)
        end
      end

      def finalize
        invoice = current_organization.invoices.draft.find_by(id: params[:id])
        return not_found_error(resource: "invoice") unless invoice

        result = Invoices::RefreshDraftAndFinalizeService.call(invoice:)
        if result.success?
          render_invoice(result.invoice)
        else
          render_error_response(result)
        end
      end

      def void
        invoice = current_organization.invoices.visible.find_by(id: params[:id])

        result = Invoices::VoidService.call(invoice: invoice, params: void_params)
        if result.success?
          render_invoice(result.invoice)
        else
          render_error_response(result)
        end
      end

      def lose_dispute
        invoice = current_organization.invoices.visible.find_by(id: params[:id])

        result = Invoices::LoseDisputeService.call(invoice:, payment_dispute_lost_at: DateTime.current)
        if result.success?
          render_invoice(result.invoice)
        else
          render_error_response(result)
        end
      end

      def retry_payment
        invoice = current_organization.invoices.visible.find_by(id: params[:id])
        return not_found_error(resource: "invoice") unless invoice

        result = Invoices::Payments::RetryService.new(
          invoice:,
          payment_method_params: retry_payment_params[:payment_method]
        ).call
        return render_error_response(result) unless result.success?

        head(:ok)
      end

      def retry
        invoice = current_organization.invoices.visible.find_by(id: params[:id])
        return not_found_error(resource: "invoice") unless invoice

        result = Invoices::RetryService.new(invoice:).call
        if result.success?
          render_invoice(result.invoice)
        else
          render_error_response(result)
        end
      end

      def resend_email
        invoice = current_organization.invoices.visible.find_by(id: params[:id])
        return not_found_error(resource: "invoice") unless invoice

        result = Emails::ResendService.call(
          resource: invoice,
          to: resend_email_params[:to],
          cc: resend_email_params[:cc],
          bcc: resend_email_params[:bcc]
        )

        if result.success?
          head(:ok)
        else
          render_error_response(result)
        end
      end

      def payment_url
        invoice = current_organization.invoices.visible.includes(:customer).find_by(id: params[:id])
        return not_found_error(resource: "invoice") unless invoice

        result = ::Invoices::Payments::GeneratePaymentUrlService.call(invoice:)

        if result.success?
          render(
            json: ::V1::PaymentProviders::InvoicePaymentSerializer.new(
              invoice,
              root_name: "invoice_payment_details",
              payment_url: result.payment_url
            )
          )
        else
          render_error_response(result)
        end
      end

      def sync_salesforce_id
        invoice = current_organization.invoices.visible.find_by(id: params[:id])
        return not_found_error(resource: "invoice") unless invoice

        result = Invoices::SyncSalesforceIdService.call(invoice:, params: sync_salesforce_id_params)

        if result.success?
          render_invoice(result.invoice)
        else
          render_error_response(result)
        end
      end

      def preview
        if preview_params[:coupons] && !preview_params[:coupons].is_a?(Array)
          return render(
            json: {
              status: 400,
              error: "coupons_must_be_an_array"
            },
            status: :bad_request
          )
        end

        if preview_params[:subscriptions] && !preview_params.to_h[:subscriptions].is_a?(Hash)
          return render(
            json: {
              status: 400,
              error: "subscriptions_must_be_an_object"
            },
            status: :bad_request
          )
        end

        billing_entity_resolver = BillingEntities::ResolveService.call(
          organization: current_organization, billing_entity_code: params[:billing_entity_code]
        )
        return render_error_response(billing_entity_resolver) unless billing_entity_resolver.success?
        billing_entity = billing_entity_resolver.billing_entity

        result = Invoices::PreviewContextService.call(
          organization: current_organization,
          billing_entity: billing_entity,
          params: preview_params.to_h.deep_symbolize_keys
        )
        return render_error_response(result) unless result.success?

        result = Invoices::PreviewService.call(
          customer: result.customer,
          subscriptions: result.subscriptions,
          applied_coupons: result.applied_coupons
        )
        if result.success?
          render(
            json: ::V1::InvoiceSerializer.new(
              result.invoice,
              root_name: "invoice",
              includes: %i[customer integration_customers credits applied_taxes preview_subscriptions preview_fees]
            )
          )
        else
          render_error_response(result)
        end
      end

      private

      def create_params
        return @create_params if defined? @create_params

        @create_params =
          params.require(:invoice)
            .permit(
              :external_customer_id,
              :currency,
              :skip_psp,
              :billing_entity_code,
              :purchase_order_number,
              fees: [
                :add_on_code,
                :invoice_display_name,
                :unit_amount_cents,
                :units,
                :description,
                :from_datetime,
                :to_datetime,
                {tax_codes: []}
              ],
              invoice_custom_section: [
                :skip_invoice_custom_sections,
                {invoice_custom_section_codes: []}
              ],
              payment_method: [
                :payment_method_type,
                :payment_method_id
              ]
            ).to_h.deep_symbolize_keys
      end

      def update_params
        params.require(:invoice).permit(
          :payment_status,
          metadata: [
            :id,
            :key,
            :value
          ]
        )
      end

      def retry_payment_params
        params.permit(
          payment_method: [
            :payment_method_type,
            :payment_method_id
          ]
        ).to_h.deep_symbolize_keys
      end

      def preview_params
        params.permit(
          :plan_code,
          :billing_time,
          :subscription_at,
          subscriptions: [
            :plan_code,
            :terminated_at,
            external_ids: []
          ],
          coupons: [
            :code,
            :name,
            :coupon_type,
            :amount_cents,
            :amount_currency,
            :percentage_rate,
            :frequency,
            :frequency_duration,
            :frequency_duration_remaining
          ],
          customer: [
            :external_id,
            :name,
            :tax_identification_number,
            :currency,
            :timezone,
            :address_line1,
            :address_line2,
            :city,
            :zipcode,
            :state,
            :country,
            shipping_address: [
              :address_line1,
              :address_line2,
              :city,
              :zipcode,
              :state,
              :country
            ],
            integration_customers: [
              :integration_type,
              :integration_code
            ]
          ]
        )
      end

      def void_params
        params.permit(:generate_credit_note, :refund_amount, :credit_amount)
      end

      def sync_salesforce_id_params
        params.permit(
          :external_id,
          :integration_code
        )
      end

      def resend_email_params
        params.permit(to: [], cc: [], bcc: [])
      end

      def render_invoice(invoice)
        render(
          json: ::V1::InvoiceSerializer.new(
            invoice,
            root_name: "invoice",
            includes: %i[customer integration_customers billing_periods subscriptions fees credits metadata applied_taxes error_details applied_invoice_custom_sections]
          )
        )
      end

      def customer
        Customer.find_by(
          external_id: create_params[:external_customer_id],
          organization_id: current_organization.id
        )
      end

      def resource_name
        "invoice"
      end
    end
  end
end
