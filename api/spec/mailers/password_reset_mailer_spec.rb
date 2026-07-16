# frozen_string_literal: true

require "rails_helper"

RSpec.describe PasswordResetMailer do
  subject(:password_reset_mailer) { described_class }

  let(:password_reset) { create(:password_reset) }

  describe "#requested" do
    specify do
      mailer = password_reset_mailer.with(password_reset:).requested

      expect(mailer.to).to eq([password_reset.user.email])
    end

    context "when user email is nil" do
      before do
        password_reset.user.update(email: nil)
      end

      it "returns a mailer with nil values" do
        mailer = password_reset_mailer.with(password_reset:).requested

        expect(mailer.to).to be_nil
      end
    end
  end
end
