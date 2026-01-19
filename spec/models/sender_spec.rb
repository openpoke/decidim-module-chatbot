# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe Sender do
    subject { sender }

    let(:organization) { create(:organization) }
    let(:setting) { create(:chatbot_setting, organization:) }
    let(:sender) { build(:chatbot_sender, setting:) }

    it { is_expected.to be_valid }

    context "without a setting" do
      let(:sender) { build(:chatbot_sender, setting: nil) }

      it { is_expected.not_to be_valid }
    end

    describe "associations" do
      it "belongs to a setting" do
        expect(sender.setting).to eq(setting)
      end

      context "with a user" do
        let(:user) { create(:user, organization:) }
        let(:sender) { build(:chatbot_sender, setting:, decidim_user: user) }

        it "belongs to the user" do
          expect(sender.decidim_user).to eq(user)
        end
      end

      context "without a user" do
        let(:sender) { build(:chatbot_sender, setting:, decidim_user: nil) }

        it "is valid without a user" do
          expect(sender).to be_valid
          expect(sender.decidim_user).to be_nil
        end
      end
    end

    describe "#current_workflow" do
      context "when current_workflow_class is set" do
        let(:sender) { build(:chatbot_sender, :with_workflow, setting:) }

        it "returns the workflow class" do
          expect(sender.current_workflow).to eq(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow)
        end
      end

      context "when current_workflow_class is nil" do
        let(:sender) { build(:chatbot_sender, setting:, current_workflow_class: nil) }

        it "returns the default workflow from setting" do
          expect(sender.current_workflow).to eq(setting.workflow)
        end
      end

      context "with an invalid workflow class" do
        let(:sender) { build(:chatbot_sender, setting:, current_workflow_class: "NonExistent::Workflow") }

        it "falls back to the setting workflow" do
          expect(sender.current_workflow).to eq(setting.workflow)
        end
      end
    end

    describe "#parent_workflow" do
      context "when parent_workflow_class is set" do
        let(:sender) { build(:chatbot_sender, :with_parent_workflow, setting:) }

        it "returns the parent workflow class" do
          expect(sender.parent_workflow).to eq(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow)
        end
      end

      context "when parent_workflow_class is nil" do
        let(:sender) { build(:chatbot_sender, setting:, parent_workflow_class: nil) }

        it "returns nil" do
          expect(sender.parent_workflow).to be_nil
        end
      end
    end

    describe "#locale" do
      context "when metadata contains locale" do
        let(:sender) { build(:chatbot_sender, setting:, metadata: { "locale" => "ca" }) }

        it "returns the locale from metadata" do
          expect(sender.locale).to eq("ca")
        end
      end

      context "when user has a locale" do
        let(:user) { create(:user, organization:, locale: "ca") }
        let(:sender) { build(:chatbot_sender, setting:, decidim_user: user, metadata: {}) }

        it "returns the user locale" do
          expect(sender.locale).to eq("ca")
        end
      end

      context "when neither metadata nor user has locale" do
        let(:sender) { build(:chatbot_sender, setting:, decidim_user: nil, metadata: {}) }

        it "returns the organization default locale" do
          expect(sender.locale).to eq(organization.default_locale)
        end
      end

      context "with locale priority" do
        let(:user) { create(:user, organization:, locale: "ca") }
        let(:sender) { build(:chatbot_sender, setting:, decidim_user: user, metadata: { "locale" => "fr" }) }

        it "prefers metadata locale over user locale" do
          expect(sender.locale).to eq("fr")
        end
      end
    end
  end
end
