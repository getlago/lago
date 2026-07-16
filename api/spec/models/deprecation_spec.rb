# frozen_string_literal: true

require "rails_helper"

RSpec.describe Deprecation, cache: :redis do
  let(:organization) { create(:organization) }
  let(:feature_name) { "event_legacy" }

  before do
    Rails.cache.write("deprecation:#{feature_name}:#{organization.id}:last_seen_at", "2024-05-22T14:58:20.280Z")
    Rails.cache.increment("deprecation:#{feature_name}:#{organization.id}:count", 101)
  end

  describe ".report" do
    it "writes to cache" do
      freeze_time do
        described_class.report(feature_name, organization.id)

        expect(Rails.cache.read("deprecation:#{feature_name}:#{organization.id}:last_seen_at")).to eq(Time.zone.now.utc)
        expect(Rails.cache.read("deprecation:#{feature_name}:#{organization.id}:count", raw: true)).to eq("102")
      end
    end
  end

  describe ".get" do
    it "returns deprecation data for an organization" do
      expect(described_class.get(feature_name, organization.id)).to eq({
        organization_id: organization.id,
        last_seen_at: "2024-05-22T14:58:20.280Z",
        count: 101
      })
    end
  end

  describe ".get_all" do
    it "returns deprecation data for all organizations" do
      expect(described_class.get_all(feature_name)).to eq([{
        organization_id: organization.id,
        last_seen_at: "2024-05-22T14:58:20.280Z",
        count: 101
      }])
    end
  end

  describe ".get_all_as_csv" do
    it "returns deprecation data for all organizations" do
      csv = "org_id,org_name,org_email,last_event_sent_at,count\n"
      csv += "#{organization.id},#{csv_safe(organization.name)},#{organization.email},2024-05-22T14:58:20.280Z,101\n"
      expect(described_class.get_all_as_csv(feature_name)).to eq(csv)
    end
  end

  describe ".reset" do
    it "deletes deprecation data for an organization" do
      described_class.reset(feature_name, organization.id)

      expect(Rails.cache.read("deprecation:#{feature_name}:#{organization.id}:last_seen_at")).to be_nil
      expect(Rails.cache.read("deprecation:#{feature_name}:#{organization.id}:count")).to be_nil
    end
  end

  describe ".reset_all" do
    it "deletes deprecation data for all organizations" do
      described_class.reset_all(feature_name)

      expect(Rails.cache.read("deprecation:#{feature_name}:#{organization.id}:last_seen_at")).to be_nil
      expect(Rails.cache.read("deprecation:#{feature_name}:#{organization.id}:count")).to be_nil
    end
  end

  def csv_safe(value)
    # Enclose the value in double quotes if it contains a comma or double quote
    if value.include?(",") || value.include?('"')
      value = value.gsub('"', '""') # Escape double quotes by doubling them
      "\"#{value}\""
    else
      value
    end
  end
end
