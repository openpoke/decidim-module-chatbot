# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot::Admin
  describe UpdateSetting do
    subject { described_class.new(form, setting) }

    let(:organization) { create(:organization) }
    let(:setting) { create(:chatbot_setting, organization:) }
    let(:participatory_process) { create(:participatory_process, :published, organization:) }
    let(:component) { create(:component, :published, participatory_space: participatory_process) }

    let(:enabled) { true }
    let(:start_workflow) { "single_participatory_space_workflow" }
    let(:config) do
      {
        "participatory_space_gid" => participatory_process.to_global_id.to_s,
        "component_id" => component.id.to_s
      }
    end

    let(:params) do
      {
        enabled:,
        start_workflow:,
        config:
      }
    end

    let(:form) do
      SettingForm.from_params(params).with_context(current_organization: organization)
    end

    describe "when form is valid" do
      it "broadcasts :ok" do
        expect { subject.call }.to broadcast(:ok)
      end

      it "updates the setting start_workflow" do
        subject.call
        setting.reload
        expect(setting.start_workflow).to eq(start_workflow)
      end

      it "updates the enabled column to true" do
        subject.call
        setting.reload
        expect(setting.enabled?).to be true
      end

      it "updates the config with participatory space GID" do
        subject.call
        setting.reload
        expect(setting.config["participatory_space_gid"]).to eq(participatory_process.to_global_id.to_s)
      end

      it "updates the config with component" do
        subject.call
        setting.reload
        expect(setting.config["component_id"]).to eq(component.id.to_s)
      end

      it "returns the setting in broadcast" do
        expect { subject.call }.to broadcast(:ok, setting)
      end
    end

    describe "when form is invalid" do
      let(:enabled) { true }
      let(:config) { { "participatory_space_gid" => "", "component_id" => "" } }

      it "broadcasts :invalid" do
        expect { subject.call }.to broadcast(:invalid)
      end

      it "does not update the setting" do
        original_config = setting.config
        subject.call
        setting.reload
        expect(setting.config).to eq(original_config)
      end
    end

    describe "when disabling chatbot" do
      let(:setting) { create(:chatbot_setting, :enabled, organization:) }
      let(:enabled) { false }
      let(:start_workflow) { "organization_welcome" }
      let(:config) { {} }

      it "broadcasts :ok" do
        expect { subject.call }.to broadcast(:ok)
      end

      it "sets enabled column to false" do
        subject.call
        setting.reload
        expect(setting.enabled?).to be false
      end
    end

    describe "config building" do
      context "when enabled with all fields" do
        it "creates correct config structure with GID" do
          subject.call
          setting.reload

          config = setting.config.with_indifferent_access
          expect(config[:participatory_space_gid]).to eq(participatory_process.to_global_id.to_s)
          expect(config[:component_id]).to eq(component.id.to_s)
        end
      end
    end

    describe "config sanitization" do
      let(:config) do
        {
          "participatory_space_gid" => participatory_process.to_global_id.to_s,
          "component_id" => component.id.to_s,
          "unknown_key" => "should be removed"
        }
      end

      it "removes unknown keys from config" do
        subject.call
        setting.reload

        config = setting.config.with_indifferent_access
        expect(config).not_to have_key(:unknown_key)
        expect(config[:participatory_space_gid]).to be_present
        expect(config[:component_id]).to be_present
      end
    end
  end
end
