# frozen_string_literal: true

require "rails_helper"

RSpec.describe Taxes::UpdateAllEuTaxesJob do
  subject { described_class.perform_now }

  let(:organization) { create(:organization, eu_tax_management: true) }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  describe ".perform" do
    it "enqueues a job for organization with EU Tax Management" do
      create(:organization, eu_tax_management: false)

      expect { subject }.to have_enqueued_job(::Taxes::UpdateOrganizationEuTaxesJob).with(organization).exactly(:once)
    end
  end
end
