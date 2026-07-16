# frozen_string_literal: true

module Webhooks
  module DunningCampaigns
    class FinishedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::DunningCampaignFinishedSerializer.new(
          object,
          root_name: object_type,
          dunning_campaign_code: options[:dunning_campaign_code]
        )
      end

      def webhook_type
        "dunning_campaign.finished"
      end

      def object_type
        "dunning_campaign"
      end
    end
  end
end
