# frozen_string_literal: true

module Api
  module V1
    class WalletsController < Api::BaseController
      include WalletActions

      def create
        wallet_create(customer)
      end

      def update
        wallet = current_organization.wallets.find_by(id: params[:id])

        wallet_update(wallet)
      end

      def terminate
        wallet = current_organization.wallets.find_by(id: params[:id])

        wallet_terminate(wallet)
      end

      def show
        wallet = current_organization.wallets.find_by(id: params[:id])

        wallet_show(wallet)
      end

      def index
        permitted_params = params.permit(:external_customer_id, :currency, billing_entity_codes: [])
        external_customer_id = permitted_params[:external_customer_id]
        currency = permitted_params[:currency]
        billing_entity_codes = permitted_params[:billing_entity_codes]

        wallet_index(external_customer_id:, currency:, billing_entity_codes:)
      end

      private

      def customer_params
        params.require(:wallet).permit(:external_customer_id)
      end

      def customer
        Customer.find_by(external_id: customer_params[:external_customer_id], organization_id: current_organization.id)
      end

      def resource_name
        "wallet"
      end
    end
  end
end
