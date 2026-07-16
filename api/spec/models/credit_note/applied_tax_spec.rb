# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNote::AppliedTax do
  subject(:applied_tax) { create(:credit_note_applied_tax) }

  describe "associations" do
    it { is_expected.to belong_to(:credit_note) }
    it { is_expected.to belong_to(:tax).optional }
    it { is_expected.to belong_to(:organization) }
  end

  it_behaves_like "paper_trail traceable"
end
