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
    let(:start_workflow) { "participatory_space" }
    let(:participatory_space_gid) { participatory_process.to_global_id.to_s }
    let(:component_id) { component.id }

    let(:params) do
      {
        enabled:,
        start_workflow:,
        participatory_space_gid:,
        component_id:
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

      it "updates the setting config with enabled true" do
        subject.call
        setting.reload
        expect(setting.enabled?).to be true
      end

      it "updates the config with participatory space" do
        subject.call
        setting.reload
        expect(setting.participatory_space).to eq(participatory_process)
      end

      it "updates the config with component" do
        subject.call
        setting.reload
        expect(setting.selected_component).to eq(component)
      end

      it "returns the setting in broadcast" do
        expect { subject.call }.to broadcast(:ok, setting)
      end
    end

    describe "when form is invalid" do
      let(:enabled) { true }
      let(:participatory_space_gid) { nil }
      let(:component_id) { nil }

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
      let(:participatory_space_gid) { nil }
      let(:component_id) { nil }

      it "broadcasts :ok" do
        expect { subject.call }.to broadcast(:ok)
      end

      it "sets enabled to false in config" do
        subject.call
        setting.reload
        expect(setting.enabled?).to be false
      end
    end

    describe "config building" do
      context "when enabled with all fields" do
        it "creates correct config structure" do
          subject.call
          setting.reload

          config = setting.config.with_indifferent_access
          expect(config[:enabled]).to be true
          expect(config[:participatory_space_type]).to eq("Decidim::ParticipatoryProcess")
          expect(config[:participatory_space_id]).to eq(participatory_process.id)
          expect(config[:component_id]).to eq(component.id)
        end
      end
    end
  end
end
