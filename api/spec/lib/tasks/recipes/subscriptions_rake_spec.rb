# frozen_string_literal: true

require "rails_helper"

require "rake"

RSpec.describe "recipes:subscriptions:terminate_all" do # rubocop:disable RSpec/DescribeClass
  let(:task) { Rake::Task["recipes:subscriptions:terminate_all"] }
  let(:organization) { create(:organization, api_keys: []) }

  before do
    Rake.application.rake_require("tasks/recipes/subscriptions")
    Rake::Task.define_task(:environment)
    task.reenable
  end

  def stub_stdin(*responses)
    allow($stdin).to receive(:gets).and_return(*responses.map { |r| "#{r}\n" })
  end

  context "when organization is not found" do
    before { stub_stdin("00000000") }

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
    end
  end

  context "when user does not confirm the organization" do
    before { stub_stdin(organization.id, "n") }

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
    end
  end

  context "when organization has no active or pending subscriptions" do
    before { stub_stdin(organization.id, "y") }

    it "finishes without doing anything" do
      expect { task.invoke }.not_to raise_error
    end
  end

  context "when organization has subscriptions in mixed states" do
    let(:customer) { create(:customer, organization:) }
    let!(:active_sub) { create(:subscription, customer:, organization:) }
    let!(:pending_sub) { create(:subscription, :pending, customer:, organization:) }
    let!(:terminated_sub) { create(:subscription, :terminated, customer:, organization:) }

    before do
      allow(Subscriptions::TerminateService).to receive(:call) do |subscription:, **|
        new_status = subscription.pending? ? :canceled : :terminated
        subscription.update!(status: new_status, terminated_at: Time.current)
        BaseResult.new
      end
    end

    context "when user confirms" do
      before { stub_stdin(organization.id, "y", "y") }

      it "terminates active subscriptions via the terminate service" do
        task.invoke
        expect(Subscriptions::TerminateService).to have_received(:call)
          .with(subscription: active_sub, async: false)
      end

      it "cancels pending subscriptions via the terminate service" do
        task.invoke
        expect(Subscriptions::TerminateService).to have_received(:call)
          .with(subscription: pending_sub, async: false)
        expect(pending_sub.reload).to be_canceled
      end

      it "does not touch already-terminated subscriptions" do
        original_updated_at = terminated_sub.updated_at
        task.invoke
        expect(terminated_sub.reload.updated_at).to eq(original_updated_at)
      end
    end

    context "when user declines confirmation" do
      before { stub_stdin(organization.id, "y", "n") }

      it "aborts without terminating or canceling" do
        expect { task.invoke }.to raise_error(SystemExit)
        expect(active_sub.reload).to be_active
        expect(pending_sub.reload).to be_pending
      end
    end

    context "when the terminate service fails" do
      let(:failure_result) do
        BaseResult.new.tap { |r| r.single_validation_failure!(error_code: "boom") }
      end

      before do
        allow(Subscriptions::TerminateService).to receive(:call).and_return(failure_result)
        stub_stdin(organization.id, "y", "y")
      end

      it "aborts and leaves remaining subs untouched" do
        expect { task.invoke }.to raise_error(SystemExit)
        expect(pending_sub.reload).to be_pending
      end
    end
  end
end
