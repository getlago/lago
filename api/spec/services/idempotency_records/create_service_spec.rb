# frozen_string_literal: true

require "rails_helper"

RSpec.describe IdempotencyRecords::CreateService do
  subject(:result) { described_class.call(idempotency_key:, resource:) }

  let(:idempotency_key) { SecureRandom.uuid }
  let(:resource) { create(:customer) }

  it "creates a new idempotency record" do
    expect { result }.to change(IdempotencyRecord, :count).by(1)
    expect(result).to be_success

    idempotency_record = result.idempotency_record
    expect(idempotency_record.id).to be_present
    expect(idempotency_record.idempotency_key).to eq(idempotency_key)
    expect(idempotency_record.resource).to eq(resource)
  end

  context "when idempotency record already exists" do
    before do
      IdempotencyRecord.create!(
        idempotency_key: idempotency_key,
        resource: resource
      )
    end

    it "returns a validation failure" do
      expect(result).to be_failure
      expect(result.error).to be_a(BaseService::ValidationFailure)
      expect(result.error.messages).to eq(idempotency_key: ["already_exists"])
    end
  end

  context "when resource is not provided" do
    let(:resource) { nil }

    it "creates an idempotency record without a resource" do
      expect { result }.to change(IdempotencyRecord, :count).by(1)
      expect(result).to be_success

      idempotency_record = result.idempotency_record
      expect(idempotency_record.resource).to be_nil
    end
  end
end
