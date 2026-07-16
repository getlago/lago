# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organizations::Sluggable do
  describe "validations" do
    subject(:organization) { build(:organization) }

    it "validates presence of slug on update" do
      persisted_org = create(:organization)
      persisted_org.slug = nil
      expect(persisted_org).not_to be_valid
      expect(persisted_org.errors[:slug]).to be_present
    end

    it "validates uniqueness of slug" do
      create(:organization, slug: "taken-slug")
      organization.slug = "taken-slug"
      expect(organization).not_to be_valid
      expect(organization.errors[:slug]).to be_present
    end

    it "validates minimum length of 3" do
      organization.slug = "ab"
      expect(organization).not_to be_valid
    end

    it "validates maximum length of 40" do
      organization.slug = "a" * 41
      expect(organization).not_to be_valid
    end

    it "validates format" do
      valid_slugs = %w[acme acme-corp a1b2 my-org-123]
      valid_slugs.each do |slug|
        organization.slug = slug
        expect(organization).to be_valid, "expected '#{slug}' to be valid"
      end

      invalid_slugs = ["-starts-with-dash", "ends-with-dash-", "UPPERCASE", "has spaces", "special!chars", "under_score"]
      invalid_slugs.each do |slug|
        organization.slug = slug
        expect(organization).not_to be_valid, "expected '#{slug}' to be invalid"
      end
    end

    it "rejects reserved slugs" do
      Organizations::Sluggable::RESERVED_SLUGS.each do |reserved|
        organization.slug = reserved
        expect(organization).not_to be_valid, "expected reserved slug '#{reserved}' to be rejected"
      end
    end

    it "skips slug validations when slug has not changed on persisted record" do
      organization = create(:organization)
      organization.name = "Updated Name"
      expect(organization).to be_valid
    end
  end

  describe "#generate_slug" do
    it "auto-generates slug from organization name" do
      organization = build(:organization, name: "Acme Corporation", slug: nil)
      organization.valid?
      expect(organization.slug).to eq("acme-corporation")
    end

    it "skips generation when slug is already present" do
      organization = build(:organization, name: "Acme Corporation", slug: "custom-slug")
      organization.valid?
      expect(organization.slug).to eq("custom-slug")
    end

    it "transliterates accented characters" do
      organization = build(:organization, name: "Société Générale", slug: nil)
      organization.valid?
      expect(organization.slug).to eq("societe-generale")
    end

    it "handles umlauts and special characters" do
      organization = build(:organization, name: "Müller & Söhne GmbH", slug: nil)
      organization.valid?
      expect(organization.slug).to eq("muller-sohne-gmbh")
    end

    it "strips special characters" do
      organization = build(:organization, name: "Tech & Co. #1 @2024!", slug: nil)
      organization.valid?
      expect(organization.slug).to eq("tech-co-1-2024")
    end

    it "cleans up consecutive and trailing dashes" do
      organization = build(:organization, name: "test ()(/&()/-.,-.,--_:_;-,-,)(/&/()&(-.,--.,-,_:;_;", slug: nil)
      organization.valid?
      expect(organization.slug).to eq("test")
    end

    it "truncates to 40 characters" do
      organization = build(:organization, name: "A Very Long Organization Name That Exceeds The Forty Character Limit", slug: nil)
      organization.valid?
      expect(organization.slug.length).to be <= 40
    end

    it "does not leave trailing hyphen after truncation" do
      organization = build(:organization, name: "Alpha Beta Gamma Delta Epsilon Zeta Eta T", slug: nil)
      organization.valid?
      expect(organization.slug).not_to end_with("-")
      expect(organization.slug).to match(Organizations::Sluggable::SLUG_FORMAT)
    end

    context "with fallback cases" do
      it "generates random slug for non-transliterable names (Cyrillic)" do
        organization = build(:organization, name: "Газпром", slug: nil)
        organization.valid?
        expect(organization.slug).to match(/\Aorg-[a-z0-9]{5}\z/)
      end

      it "generates random slug for non-transliterable names (CJK)" do
        organization = build(:organization, name: "日本企業", slug: nil)
        organization.valid?
        expect(organization.slug).to match(/\Aorg-[a-z0-9]{5}\z/)
      end

      it "generates random slug for purely numeric names" do
        organization = build(:organization, name: "12345", slug: nil)
        organization.valid?
        expect(organization.slug).to match(/\Aorg-[a-z0-9]{5}\z/)
      end

      it "generates random slug for reserved words" do
        organization = build(:organization, name: "Admin", slug: nil)
        organization.valid?
        expect(organization.slug).to match(/\Aorg-[a-z0-9]{5}\z/)
      end

      it "generates random slug for names shorter than 3 characters" do
        organization = build(:organization, name: "AB", slug: nil)
        organization.valid?
        expect(organization.slug).to match(/\Aorg-[a-z0-9]{5}\z/)
      end

      it "generates random slug for blank names" do
        organization = build(:organization, name: "🚀", slug: nil)
        organization.valid?
        expect(organization.slug).to match(/\Aorg-[a-z0-9]{5}\z/)
      end
    end

    context "with collision handling" do
      it "appends random suffix on collision" do
        create(:organization, slug: "acme-corp")
        organization = build(:organization, name: "Acme Corp", slug: nil)
        organization.valid?
        expect(organization.slug).to match(/\Aacme-corp-[a-z0-9]{3}\z/)
      end

      it "generates unique slugs for organizations with the same name" do
        org1 = create(:organization, name: "Acme Corp", slug: nil)
        org2 = build(:organization, name: "Acme Corp", slug: nil)
        org2.valid?
        expect(org2.slug).not_to eq(org1.slug)
        expect(org2.slug).to start_with("acme-corp")
      end

      it "does not produce double hyphens when base ends with hyphen" do
        # "Alpha Beta Gamma Delta Epsilon Zeta Eta Theta" → truncated to 40 → "alpha-beta-gamma-delta-epsilon-zeta-eta-" → cleaned → "alpha-beta-gamma-delta-epsilon-zeta-eta"
        # On collision, base truncated to 36 → "alpha-beta-gamma-delta-epsilon-zeta-" → cleaned → "alpha-beta-gamma-delta-epsilon-zeta"
        create(:organization, slug: "alpha-beta-gamma-delta-epsilon-zeta-eta")
        organization = build(:organization, name: "Alpha Beta Gamma Delta Epsilon Zeta Eta Theta", slug: nil)
        organization.valid?
        expect(organization.slug).not_to include("--")
      end
    end
  end
end
