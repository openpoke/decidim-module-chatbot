# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Workflows
      describe OrganizationWelcomeWorkflow do
        subject { described_class.new(adapter:, message:) }
        let(:adapter) { instance_double("Decidim::Chatbot::Providers::BaseAdapter") }
        let(:message) { instance_double("Decidim::Chatbot::Message") }

        describe "#start" do
          let(:adapter_message) { instance_double("Decidim::Chatbot::Providers::BaseEnvelope") }

          it "processes a welcome message" do
            expect(subject).to be_a(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow)
          end
        end
      end
    end
  end
end
