# frozen_string_literal: true

module Api
  module V1
    module Analytics
      class OverdueBalancesController < BaseController
        def index
          @result = ::Analytics::OverdueBalancesService.call(current_organization, **filters)

          super
        end

        private

        def filters
          {
            external_customer_id: params[:external_customer_id],
            currency: params[:currency]&.upcase,
            months: params[:months],
            billing_entity_id: billing_entity&.id
          }
        end
      end
    end
  end
end
