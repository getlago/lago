# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrderForms::ExpireOrderFormJob, job: true do
  let(:order_form) { create(:order_form, :expired_yesterday) }

  it "calls ExpireService" do
    allow(OrderForms::ExpireService).to receive(:call!)

    described_class.perform_now(order_form)

    expect(OrderForms::ExpireService).to have_received(:call!).with(order_form:)
  end
end
