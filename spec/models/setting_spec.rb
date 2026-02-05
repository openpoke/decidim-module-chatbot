# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe Setting do
    subject { setting }

    let(:organization) { create(:organization) }
    let(:setting) { build(:chatbot_setting, organization:) }

    it { is_expected.to be_valid }

    context "without an organization" do
      let(:setting) { build(:chatbot_setting, organization: nil) }

      it { is_expected.not_to be_valid }
    end

    context "without a provider" do
      let(:setting) { build(:chatbot_setting, provider: nil) }

      it { is_expected.not_to be_valid }
    end

    describe "associations" do
      let!(:setting) { create(:chatbot_setting, organization:) }
      let!(:sender) { create(:chatbot_sender, setting:) }

      it "has many senders" do
        expect(setting.senders).to include(sender)
      end

      it "destroys dependent senders when setting is destroyed" do
        expect { setting.destroy }.to change(Sender, :count).by(-1)
      end

      context "with messages" do
        let!(:message) { create(:chatbot_message, setting:, sender: nil) }

        it "has many messages" do
          expect(setting.messages).to include(message)
        end

        it "destroys dependent messages when setting is destroyed" do
          expect { setting.destroy }.to change(Message, :count).by(-1)
        end
      end
    end

    describe "#adapter_manifest" do
      let(:setting) { create(:chatbot_setting, organization:, provider: "whatsapp") }

      it "returns the adapter manifest for the provider" do
        expect(setting.adapter_manifest).to be_present
        expect(setting.adapter_manifest.name).to eq(:whatsapp)
      end

      context "with unknown provider" do
        let(:setting) { build(:chatbot_setting, organization:, provider: "unknown") }

        it "returns nil" do
          expect(setting.adapter_manifest).to be_nil
        end
      end
    end

    describe "#workflow" do
      let(:setting) { create(:chatbot_setting, organization:, start_workflow: "organization_welcome") }

      it "returns the workflow class for the start_workflow" do
        expect(setting.workflow).to eq(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow)
      end
    end

    describe "#enabled?" do
      context "when enabled column is true" do
        let(:setting) { build(:chatbot_setting, organization:, enabled: true) }

        it { expect(setting.enabled?).to be true }
      end

      context "when enabled column is false" do
        let(:setting) { build(:chatbot_setting, organization:, enabled: false) }

        it { expect(setting.enabled?).to be false }
      end

      context "with default value" do
        let(:setting) { build(:chatbot_setting, organization:) }

        it { expect(setting.enabled?).to be false }
      end
    end

    describe "#toggle_enabled!" do
      let!(:setting) { create(:chatbot_setting, organization:, enabled: false) }

      it "toggles from false to true" do
        setting.toggle_enabled!
        expect(setting.reload.enabled?).to be true
      end

      it "toggles from true to false" do
        setting.update!(enabled: true)
        setting.toggle_enabled!
        expect(setting.reload.enabled?).to be false
      end

      it "persists the change" do
        setting.toggle_enabled!
        expect(Setting.find(setting.id).enabled?).to be true
      end
    end
  end
end
