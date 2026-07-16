# frozen_string_literal: true

module V1
  module Customers
    class ProjectedUsageSerializer < ModelSerializer
      def serialize
        payload = {
          from_datetime: model.from_datetime,
          to_datetime: model.to_datetime,
          issuing_date: model.issuing_date,
          currency: model.currency,
          amount_cents: model.amount_cents,
          projected_amount_cents: projected_amount_cents,
          total_amount_cents: model.total_amount_cents,
          taxes_amount_cents: model.taxes_amount_cents,
          lago_invoice_id: nil
        }

        payload.merge!(charges_usage)
        payload
      end

      def projected_amount_cents
        fee_groups = model.fees.group_by(&:charge_id).values
        fee_groups.sum do |fee_group|
          projection_result = ::Fees::ProjectionService.call(fees: fee_group).raise_if_error!
          projection_result.projected_amount_cents
        end
      end

      private

      def charges_usage
        {
          charges_usage: ::V1::Customers::ProjectedChargeUsageSerializer.new(
            model.fees
          ).serialize
        }
      end
    end
  end
end
