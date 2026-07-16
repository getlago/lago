# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddOnsQuery do
  subject(:result) do
    described_class.call(organization:, pagination:, search_term:)
  end

  let(:returned_ids) { result.add_ons.pluck(:id) }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:add_on_first) { create(:add_on, organization:, name: "defgh", code: "11") }
  let(:add_on_second) { create(:add_on, organization:, name: "abcde", code: "22") }
  let(:add_on_third) { create(:add_on, organization:, name: "presuv", code: "33") }
  let(:pagination) { {page: 1, limit: 10} }
  let(:search_term) { nil }

  before do
    add_on_first
    add_on_second
    add_on_third
  end

  it "returns all add_ons" do
    expect(result.add_ons.count).to eq(3)
    expect(returned_ids).to include(add_on_first.id)
    expect(returned_ids).to include(add_on_second.id)
    expect(returned_ids).to include(add_on_third.id)
  end

  context "when add ons have the same values for the ordering criteria" do
    let(:add_on_second) do
      create(
        :add_on,
        organization:,
        id: "00000000-0000-0000-0000-000000000000",
        name: "abcde",
        code: "22",
        created_at: add_on_first.created_at
      )
    end

    it "returns a consistent list" do
      expect(result).to be_success
      expect(returned_ids.count).to eq(3)
      expect(returned_ids).to include(add_on_first.id)
      expect(returned_ids).to include(add_on_second.id)
      expect(returned_ids.index(add_on_first.id)).to be > returned_ids.index(add_on_second.id)
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 2} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.add_ons.count).to eq(1)
      expect(result.add_ons.current_page).to eq(2)
      expect(result.add_ons.prev_page).to eq(1)
      expect(result.add_ons.next_page).to be_nil
      expect(result.add_ons.total_pages).to eq(2)
      expect(result.add_ons.total_count).to eq(3)
    end
  end

  context "when searching for /de/ term" do
    let(:search_term) { "de" }

    it "returns only two add_ons" do
      expect(result.add_ons.count).to eq(2)
      expect(returned_ids).to include(add_on_first.id)
      expect(returned_ids).to include(add_on_second.id)
      expect(returned_ids).not_to include(add_on_third.id)
    end
  end

  context "when searching for /1/ term" do
    let(:search_term) { "1" }

    it "returns only two add_ons" do
      expect(result.add_ons.count).to eq(1)
      expect(returned_ids).to include(add_on_first.id)
      expect(returned_ids).not_to include(add_on_second.id)
      expect(returned_ids).not_to include(add_on_third.id)
    end
  end
end
