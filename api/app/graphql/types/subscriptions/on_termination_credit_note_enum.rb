# frozen_string_literal: true

module Types
  module Subscriptions
    class OnTerminationCreditNoteEnum < Types::BaseEnum
      Subscription::ON_TERMINATION_CREDIT_NOTES.each_key do |reason|
        value reason
      end
    end
  end
end
