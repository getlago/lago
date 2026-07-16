# frozen_string_literal: true

module Commitments
  module Minimum
    module InArrears
      class DatesService < Commitments::DatesService
        def current_usage
          invoice_subscription.subscription.terminated?
        end
      end
    end
  end
end
