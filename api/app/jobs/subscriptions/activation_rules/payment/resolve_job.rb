# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    module Payment
      class ResolveJob < ApplicationJob
        queue_as do
          if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
            :billing
          else
            :default
          end
        end

        def perform(subscription, invoice, payment_status)
          Payment::ResolveService.call!(subscription:, invoice:, payment_status:)
        end
      end
    end
  end
end
