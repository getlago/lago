# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetricFilter do
  subject(:billable_metric_filter) { build(:billable_metric_filter) }

  it_behaves_like "paper_trail traceable"

  it { is_expected.to belong_to(:billable_metric) }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_many(:filter_values).dependent(:destroy) }
  it { is_expected.to have_many(:charge_filters).through(:filter_values) }

  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_presence_of(:values) }
end
