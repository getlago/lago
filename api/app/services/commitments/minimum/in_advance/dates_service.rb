# frozen_string_literal: true

module Commitments
  module Minimum
    module InAdvance
      class DatesService < Commitments::DatesService
        def current_usage
          true
        end
      end
    end
  end
end
