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
      context "when config has enabled set to true" do
        let(:setting) { build(:chatbot_setting, organization:, config: { "enabled" => true }) }

        it { expect(setting.enabled?).to be true }
      end

      context "when config has enabled set to false" do
        let(:setting) { build(:chatbot_setting, organization:, config: { "enabled" => false }) }

        it { expect(setting.enabled?).to be false }
      end

      context "when config is empty" do
        let(:setting) { build(:chatbot_setting, organization:, config: {}) }

        it { expect(setting.enabled?).to be false }
      end

      context "when config is nil" do
        let(:setting) { build(:chatbot_setting, organization:, config: nil) }

        it { expect(setting.enabled?).to be false }
      end
    end

    describe "#participatory_space" do
      let!(:participatory_process) { create(:participatory_process, organization:) }

      context "when config has valid participatory space" do
        let(:setting) do
          build(:chatbot_setting, organization:, config: {
                  "participatory_space_type" => "Decidim::ParticipatoryProcess",
                  "participatory_space_id" => participatory_process.id
                })
        end

        it "returns the participatory space" do
          expect(setting.participatory_space).to eq(participatory_process)
        end
      end

      context "when participatory_space_type is missing" do
        let(:setting) do
          build(:chatbot_setting, organization:, config: {
                  "participatory_space_id" => participatory_process.id
                })
        end

        it "returns nil" do
          expect(setting.participatory_space).to be_nil
        end
      end

      context "when participatory_space_id is missing" do
        let(:setting) do
          build(:chatbot_setting, organization:, config: {
                  "participatory_space_type" => "Decidim::ParticipatoryProcess"
                })
        end

        it "returns nil" do
          expect(setting.participatory_space).to be_nil
        end
      end

      context "when participatory_space_type is invalid class" do
        let(:setting) do
          build(:chatbot_setting, organization:, config: {
                  "participatory_space_type" => "InvalidClass",
                  "participatory_space_id" => participatory_process.id
                })
        end

        it "returns nil" do
          expect(setting.participatory_space).to be_nil
        end
      end

      context "when participatory space does not exist" do
        let(:setting) do
          build(:chatbot_setting, organization:, config: {
                  "participatory_space_type" => "Decidim::ParticipatoryProcess",
                  "participatory_space_id" => 999_999
                })
        end

        it "returns nil" do
          expect(setting.participatory_space).to be_nil
        end
      end

      context "when config is empty" do
        let(:setting) { build(:chatbot_setting, organization:, config: {}) }

        it "returns nil" do
          expect(setting.participatory_space).to be_nil
        end
      end
    end

    describe "#selected_component" do
      let!(:participatory_process) { create(:participatory_process, organization:) }
      let!(:component) { create(:component, participatory_space: participatory_process) }

      context "when config has valid component" do
        let(:setting) do
          build(:chatbot_setting, organization:, config: {
                  "participatory_space_type" => "Decidim::ParticipatoryProcess",
                  "participatory_space_id" => participatory_process.id,
                  "component_id" => component.id
                })
        end

        it "returns the component" do
          expect(setting.selected_component).to eq(component)
        end
      end

      context "when component_id is missing" do
        let(:setting) do
          build(:chatbot_setting, organization:, config: {
                  "participatory_space_type" => "Decidim::ParticipatoryProcess",
                  "participatory_space_id" => participatory_process.id
                })
        end

        it "returns nil" do
          expect(setting.selected_component).to be_nil
        end
      end

      context "when participatory space is not configured" do
        let(:setting) do
          build(:chatbot_setting, organization:, config: {
                  "component_id" => component.id
                })
        end

        it "returns nil" do
          expect(setting.selected_component).to be_nil
        end
      end

      context "when component does not exist" do
        let(:setting) do
          build(:chatbot_setting, organization:, config: {
                  "participatory_space_type" => "Decidim::ParticipatoryProcess",
                  "participatory_space_id" => participatory_process.id,
                  "component_id" => 999_999
                })
        end

        it "returns nil" do
          expect(setting.selected_component).to be_nil
        end
      end

      context "when component belongs to different space" do
        let!(:other_process) { create(:participatory_process, organization:) }
        let!(:other_component) { create(:component, participatory_space: other_process) }
        let(:setting) do
          build(:chatbot_setting, organization:, config: {
                  "participatory_space_type" => "Decidim::ParticipatoryProcess",
                  "participatory_space_id" => participatory_process.id,
                  "component_id" => other_component.id
                })
        end

        it "returns nil" do
          expect(setting.selected_component).to be_nil
        end
      end
    end

    describe "#write_action" do
      context "when write_action is set" do
        let(:setting) { build(:chatbot_setting, organization:, config: { "write_action" => "create_proposal" }) }

        it "returns the write action" do
          expect(setting.write_action).to eq("create_proposal")
        end
      end

      context "when write_action is nil" do
        let(:setting) { build(:chatbot_setting, organization:, config: { "write_action" => nil }) }

        it "returns nil" do
          expect(setting.write_action).to be_nil
        end
      end

      context "when write_action is not set" do
        let(:setting) { build(:chatbot_setting, organization:, config: {}) }

        it "returns nil" do
          expect(setting.write_action).to be_nil
        end
      end
    end
  end
end
