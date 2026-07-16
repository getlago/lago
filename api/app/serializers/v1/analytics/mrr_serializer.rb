# frozen_string_literal: true

module V1
  module Analytics
    class MrrSerializer < ModelSerializer
      def serialize
        {
          month: model["month"],
          amount_cents: model["amount_cents"],
          currency: model["currency"]
        }
      end
    end
  end
end
