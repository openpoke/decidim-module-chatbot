# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe ApplicationHelper do
    describe "#delegate_workflow_options" do
      it "returns workflow options" do
        result = helper.delegate_workflow_options
        expect(result).to be_an(Array)
        expect(result.first).to be_an(Array)
        expect(result.first.length).to eq(2)
      end

      it "includes registered workflows" do
        result = helper.delegate_workflow_options
        workflow_names = result.map(&:last)
        expect(workflow_names).to include("organization_welcome")
        expect(workflow_names).to include("single_participatory_space_workflow")
      end

      context "when excluding a workflow" do
        it "excludes the specified workflow from options" do
          result = helper.delegate_workflow_options(exclude_workflow: :organization_welcome)
          workflow_names = result.map(&:last)
          expect(workflow_names).not_to include("organization_welcome")
          expect(workflow_names).to include("single_participatory_space_workflow")
        end
      end
    end
  end
end
