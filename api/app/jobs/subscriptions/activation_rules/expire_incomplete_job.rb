# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    class ExpireIncompleteJob < ApplicationJob
      queue_as do
        if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
          :billing
        else
          :default
        end
      end

      unique :until_executed, on_conflict: :log

      def perform(subscription)
        Subscriptions::ActivationRules::ExpireService.call!(subscription:)
      end
    end
  end
end
