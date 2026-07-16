# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::SubscriptionActivity do
  it do
    expect(subject).to belong_to(:organization)
    expect(subject).to belong_to(:subscription)
    expect(subject).to have_db_column(:enqueued).with_options(null: false, default: false)
    expect(subject).to have_db_column(:inserted_at).with_options(null: false)

    expect(subject).to have_db_index(:subscription_id).unique(true)
    expect(subject).to have_db_index([:organization_id, :enqueued])
  end
end
