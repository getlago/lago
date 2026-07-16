# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::ActivityLogs::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:activity_id).of_type("ID!")
    expect(subject).to have_field(:activity_object).of_type("JSON")
    expect(subject).to have_field(:activity_object_changes).of_type("JSON")
    expect(subject).to have_field(:activity_source).of_type("ActivitySourceEnum!")
    expect(subject).to have_field(:activity_type).of_type("ActivityTypeEnum!")
    expect(subject).to have_field(:api_key).of_type("SanitizedApiKey")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:external_customer_id).of_type("String")
    expect(subject).to have_field(:external_subscription_id).of_type("String")
    expect(subject).to have_field(:logged_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:organization).of_type("Organization")
    expect(subject).to have_field(:resource).of_type("ActivityLogResourceObject")
    expect(subject).to have_field(:user_email).of_type("String")
  end
end
