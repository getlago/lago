# frozen_string_literal: true

module Api
  module V1
    class WalletTransactionsController < Api::BaseController
      def create
        result = WalletTransactions::CreateFromParamsService.call(
          organization: current_organization,
          params: input_params
        )

        if result.success?
          render(
            json: ::CollectionSerializer.new(
              result.wallet_transactions,
              ::V1::WalletTransactionSerializer,
              collection_name: "wallet_transactions"
            )
          )
        else
          render_error_response(result)
        end
      end

      def index
        result = WalletTransactionsQuery.call(
          organization: current_organization,
          wallet_id: params[:id],
          pagination: {
            page: params[:page],
            limit: params[:per_page] || PER_PAGE
          },
          filters: {
            status: params[:status],
            transaction_type: params[:transaction_type],
            transaction_status: params[:transaction_status]
          }
        )

        return render_error_response(result) unless result.success?

        render(
          json: ::CollectionSerializer.new(
            result.wallet_transactions.includes(:billing_entity, wallet: {customer: :billing_entity}),
            ::V1::WalletTransactionSerializer,
            collection_name: "wallet_transactions",
            meta: pagination_metadata(result.wallet_transactions)
          )
        )
      end

      def show
        wallet_transaction = current_organization.wallet_transactions.find_by(
          id: params[:id]
        )

        return not_found_error(resource: "wallet_transaction") unless wallet_transaction

        render(
          json: ::V1::WalletTransactionSerializer.new(
            wallet_transaction,
            root_name: "wallet_transaction",
            includes: %i[applied_invoice_custom_sections]
          )
        )
      end

      def payment_url
        wallet_transaction = current_organization.wallet_transactions.find_by(id: params[:id])
        result = ::WalletTransactions::Payments::GeneratePaymentUrlService.call(wallet_transaction:)

        if result.success?
          render(
            json: ::V1::PaymentProviders::WalletTransactionPaymentSerializer.new(
              wallet_transaction,
              root_name: "wallet_transaction_payment_details",
              payment_url: result.payment_url
            )
          )
        else
          render_error_response(result)
        end
      end

      def consumptions
        wallet_transaction_consumptions(direction: :consumptions)
      end

      def fundings
        wallet_transaction_consumptions(direction: :fundings)
      end

      private

      def wallet_transaction_consumptions(direction:)
        result = WalletTransactionConsumptionsQuery.call(
          organization: current_organization,
          pagination: {page: params[:page], limit: params[:per_page] || PER_PAGE},
          filters: {
            wallet_transaction_id: params[:id],
            direction: direction.to_s
          }
        )

        return render_error_response(result) unless result.success?

        wallet_transaction_direction = (direction == :consumptions) ? :outbound_wallet_transaction : :inbound_wallet_transaction
        preloads = {wallet_transaction_direction => [:billing_entity, {wallet: [:billing_entity, {customer: :billing_entity}]}]}
        collection_name = (direction == :consumptions) ? "wallet_transaction_consumptions" : "wallet_transaction_fundings"

        render(
          json: ::CollectionSerializer.new(
            result.wallet_transaction_consumptions.includes(preloads),
            ::V1::WalletTransactionConsumptionSerializer,
            collection_name:,
            meta: pagination_metadata(result.wallet_transaction_consumptions),
            includes: [wallet_transaction_direction]
          )
        )
      end

      def input_params
        @input_params ||= params.require(:wallet_transaction).permit(
          :wallet_id,
          :paid_credits,
          :granted_credits,
          :voided_credits,
          :invoice_requires_successful_payment,
          :name,
          :ignore_paid_top_up_limits,
          :priority,
          payment_method: [
            :payment_method_type,
            :payment_method_id
          ],
          metadata: [
            :key,
            :value
          ],
          invoice_custom_section: [
            :skip_invoice_custom_sections,
            {invoice_custom_section_codes: []}
          ]
        )
      end

      def resource_name
        "wallet_transaction"
      end
    end
  end
end
