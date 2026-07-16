# frozen_string_literal: true

module Lago
  module Adyen
    class Params
      attr_reader :params

      def initialize(params = {})
        @params = params.to_h
      end

      def to_h
        default_params.merge(params)
      end

      private

      def default_params
        {
          applicationInfo: {
            externalPlatform: {
              name: "Lago",
              integrator: "Lago"
            },
            merchantApplication: {
              name: "Lago"
            }
          }
        }
      end
    end
  end
end
