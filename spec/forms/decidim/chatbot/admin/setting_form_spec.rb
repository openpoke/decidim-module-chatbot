# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot::Admin
  describe SettingForm do
    subject { form }

    let(:organization) { create(:organization) }

    let(:enabled) { false }
    let(:start_workflow) { "single_participatory_space" }
    let(:config) { {} }

    let(:params) do
      {
        enabled:,
        start_workflow:,
        config:
      }
    end

    let(:form) do
      described_class.from_params(params).with_context(current_organization: organization)
    end

    describe "validations" do
      context "when all params are valid" do
        it { is_expected.to be_valid }
      end

      context "without start_workflow" do
        let(:start_workflow) { nil }

        it { is_expected.not_to be_valid }

        it "adds error on start_workflow" do
          subject.valid?
          expect(subject.errors[:start_workflow]).not_to be_empty
        end
      end
    end

    describe "#map_model" do
      let(:setting) { create(:chatbot_setting, :enabled, organization:) }

      let(:form) do
        described_class.from_model(setting).with_context(current_organization: organization)
      end

      it "maps enabled correctly" do
        expect(form.enabled).to be true
      end

      it "maps start_workflow correctly" do
        expect(form.start_workflow).to eq(setting.start_workflow)
      end

      it "maps config correctly" do
        expect(form.config).to respond_to(:[])
      end

      context "when setting is disabled" do
        let(:setting) { create(:chatbot_setting, organization:, enabled: false) }

        it "maps enabled as false" do
          expect(form.enabled).to be false
        end
      end
    end

    describe "#available_workflows" do
      it "returns an array of workflow options" do
        workflows = form.available_workflows
        expect(workflows).to be_an(Array)
        expect(workflows.first).to be_an(Array)
        expect(workflows.first.length).to eq(2)
      end
    end

    describe "#workflow_manifest" do
      it "returns the manifest for the selected workflow" do
        expect(form.workflow_manifest).to be_present
        expect(form.workflow_manifest.name).to eq(:single_participatory_space)
      end
    end

    describe "#workflow_config" do
      it "returns empty hash by default" do
        expect(form.workflow_config).to eq({})
      end
    end
  end
end
