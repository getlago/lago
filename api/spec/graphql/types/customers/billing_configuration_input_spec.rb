# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Customers::BillingConfigurationInput do
  subject { described_class }

  it { is_expected.to accept_argument(:document_locale).of_type("String") }
  it { is_expected.to accept_argument(:subscription_invoice_issuing_date_anchor).of_type("CustomerSubscriptionInvoiceIssuingDateAnchorEnum") }
  it { is_expected.to accept_argument(:subscription_invoice_issuing_date_adjustment).of_type("CustomerSubscriptionInvoiceIssuingDateAdjustmentEnum") }
end
