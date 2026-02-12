# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Workflows
      describe OrganizationWelcomeWorkflow do
        subject { described_class.new(adapter:, message:) }

        let(:organization) { create(:organization, name: { en: "Test Organization" }, description: { en: "Test Description" }) }
        let(:setting) { create(:chatbot_setting, organization:, config: setting_config) }
        let(:setting_config) { {} }
        let(:sender) { create(:chatbot_sender, setting:) }
        let(:message) { create(:chatbot_message, setting:, sender:) }
        let(:adapter) { instance_double(Providers::Whatsapp::Adapter) }
        let(:received_message) do
          instance_double(
            Providers::Whatsapp::MessageNormalizer,
            from: "123456789",
            message_id: "msg-123",
            user_text?: true,
            actionable?: false,
            acknowledgeable?: true,
            button_id: nil
          )
        end

        before do
          allow(adapter).to receive(:received_message).and_return(received_message)
          allow(adapter).to receive(:mark_as_read!)
          allow(adapter).to receive(:send_message!)
        end

        describe "#initialize" do
          it "creates an instance of OrganizationWelcomeWorkflow" do
            expect(subject).to be_a(described_class)
          end
        end

        describe "#start" do
          context "when user sends a text message" do
            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "sends a welcome message with organization info" do
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  body: a_string_including("Test Organization"),
                  preview_url: true
                )
              )
              subject.start
            end

            it "marks the message as read" do
              expect(adapter).to receive(:mark_as_read!)
              subject.start
            end
          end
        end

        describe "welcome message content" do
          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "includes organization name in bold" do
            expect(adapter).to receive(:send_message!) do |args|
              expect(args[:body]).to include("*Test Organization*")
            end
            subject.start
          end

          it "includes the organization description" do
            expect(adapter).to receive(:send_message!) do |args|
              expect(args[:body]).to include("Test Description")
            end
            subject.start
          end

          it "includes the root URL" do
            expect(adapter).to receive(:send_message!) do |args|
              expect(args[:body]).to include(organization.host)
            end
            subject.start
          end

          it "sets preview_url to true" do
            expect(adapter).to receive(:send_message!) do |args|
              expect(args[:preview_url]).to be true
            end
            subject.start
          end
        end

        describe "organization content sanitization" do
          let(:organization) do
            create(:organization,
                   name: { en: "Organization" },
                   description: { en: "<p>Description with <strong>HTML</strong></p>" })
          end

          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "strips HTML tags from description" do
            expect(adapter).to receive(:send_message!) do |args|
              expect(args[:body]).not_to include("<p>")
              expect(args[:body]).not_to include("<strong>")
              expect(args[:body]).to include("Description with HTML")
            end
            subject.start
          end
        end

        describe "#process_action_input" do
          before do
            allow(received_message).to receive(:user_text?).and_return(false)
            allow(received_message).to receive(:actionable?).and_return(true)
            allow(received_message).to receive(:button_id).and_return("some_old_button")
          end

          it "re-sends the welcome message (delegates to process_user_input)" do
            expect(adapter).to receive(:send_message!).with(
              hash_including(
                body: a_string_including("Test Organization"),
                preview_url: true
              )
            )
            subject.start
          end
        end

        describe "custom_text in config" do
          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          context "when custom_text is present in config" do
            let(:setting_config) { { "custom_text" => "Welcome to our custom chatbot!" } }

            it "uses custom_text in body" do
              expect(adapter).to receive(:send_message!) do |args|
                expect(args[:body]).to include("Welcome to our custom chatbot!")
              end
              subject.start
            end
          end

          context "when custom_text is empty" do
            let(:setting_config) { { "custom_text" => "" } }

            it "falls back to organization description" do
              expect(adapter).to receive(:send_message!) do |args|
                expect(args[:body]).to include("Test Description")
              end
              subject.start
            end
          end

          context "when custom_text is blank" do
            let(:setting_config) { { "custom_text" => "   " } }

            it "falls back to organization description" do
              expect(adapter).to receive(:send_message!) do |args|
                expect(args[:body]).to include("Test Description")
              end
              subject.start
            end
          end
        end
      end
    end
  end
end
