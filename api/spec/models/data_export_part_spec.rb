# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataExportPart do
  it { is_expected.to belong_to(:data_export) }
  it { is_expected.to belong_to(:organization) }
end
