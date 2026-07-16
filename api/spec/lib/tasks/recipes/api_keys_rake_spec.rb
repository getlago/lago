# frozen_string_literal: true

require "rails_helper"

require "rake"

RSpec.describe "recipes:api_keys:expire_all" do # rubocop:disable RSpec/DescribeClass
  let(:task) { Rake::Task["recipes:api_keys:expire_all"] }
  let(:organization) { create(:organization, api_keys: []) }

  before do
    Rake.application.rake_require("tasks/recipes/api_keys")
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

  context "when organization has no active api keys" do
    before { stub_stdin(organization.id, "y") }

    it "finishes without expiring anything" do
      expect { task.invoke }.not_to raise_error
    end
  end

  context "when organization has active api keys" do
    let!(:key_one) { create(:api_key, organization:) }
    let!(:key_two) { create(:api_key, organization:) }
    let!(:already_expired_key) { create(:api_key, :expired, organization:) }

    before { allow(ApiKeys::DestroyService).to receive(:call).and_call_original }

    context "when user confirms" do
      before { stub_stdin(organization.id, "y", "y") }

      it "expires all active keys via DestroyService with force: true" do
        task.invoke

        expect(ApiKeys::DestroyService).to have_received(:call).with(key_one, force: true)
        expect(ApiKeys::DestroyService).to have_received(:call).with(key_two, force: true)
        expect(key_one.reload).to be_expired
        expect(key_two.reload).to be_expired
      end

      it "does not touch already-expired keys" do
        original_updated_at = already_expired_key.updated_at
        task.invoke
        expect(ApiKey.unscoped.find(already_expired_key.id).updated_at)
          .to eq(original_updated_at)
      end
    end

    context "when DestroyService fails for a key" do
      let(:failure_result) do
        ApiKeys::DestroyService::Result.new.tap { |r| r.single_validation_failure!(error_code: "boom") }
      end

      before do
        allow(ApiKeys::DestroyService).to receive(:call).and_return(failure_result)
        stub_stdin(organization.id, "y", "y")
      end

      it "aborts" do
        expect { task.invoke }.to raise_error(SystemExit)
      end
    end

    context "when user declines confirmation" do
      before { stub_stdin(organization.id, "y", "n") }

      it "aborts without expiring keys" do
        expect { task.invoke }.to raise_error(SystemExit)
        expect(key_one.reload.expires_at).to be_nil
        expect(key_two.reload.expires_at).to be_nil
      end
    end
  end
end
