# frozen_string_literal: true

require "spec_helper"
require "decidim/proposals/test/factories"

module Decidim
  module Chatbot
    module Workflows
      describe CommentsWorkflow do
        subject { described_class.new(adapter:, message:, **workflow_options) }

        let(:organization) { create(:organization) }
        let!(:participatory_process) { create(:participatory_process, :with_steps, organization:) }
        let!(:proposals_component) { create(:proposal_component, participatory_space: participatory_process) }
        let!(:proposal) do
          create(:proposal,
                 component: proposals_component,
                 title: { en: "My Test Proposal" },
                 body: { en: "Proposal body text" },
                 published_at: Time.current)
        end
        let(:setting_config) do
          {
            participatory_space_gid: participatory_process.to_global_id.to_s,
            component_id: proposals_component.id
          }
        end
        let(:workflow_options) { { resource_gid: proposal.to_global_id.to_s } }
        let(:setting) { create(:chatbot_setting, organization:, enabled: true, config: setting_config) }
        let(:sender) { create(:chatbot_sender, setting:) }
        let(:chatbot_message) { create(:chatbot_message, setting:, sender:) }
        let(:message) { chatbot_message }
        let(:adapter) { instance_double(Providers::Whatsapp::Adapter) }
        let(:received_message) do
          instance_double(
            Providers::Whatsapp::MessageNormalizer,
            from: "123456789",
            message_id: "msg-123",
            user_text?: true,
            actionable?: false,
            acknowledgeable?: true,
            button_id: nil,
            body: "This is my comment"
          )
        end

        before do
          allow(adapter).to receive(:received_message).and_return(received_message)
          allow(adapter).to receive(:mark_as_read!)
          allow(adapter).to receive(:mark_as_responding!)
          allow(adapter).to receive(:send_message!)
        end

        describe "#process_user_input" do
          context "when force_welcome is true" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "sends instructions message with proposal title" do
              expected_text = I18n.t("decidim.chatbot.workflows.comments.instructions", title: "*My Test Proposal*")
              expect(adapter).to receive(:send_message!).with(expected_text)
              subject.start(true)
            end
          end

          context "when user sends a text message (comment text)" do
            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "stores the comment in current_workflow_options" do
              subject.start
              sender.reload
              expect(sender.current_workflow_options["comment"]).to eq("This is my comment")
            end

            it "sends confirmation with interactive buttons" do
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  type: :interactive_buttons,
                  body_text: a_string_including(I18n.t("decidim.chatbot.workflows.comments.comment_received")),
                  buttons: array_including(
                    hash_including(id: "submit"),
                    hash_including(id: "exit"),
                    hash_including(id: "reset")
                  )
                )
              )
              subject.start
            end

            it "includes the user's comment text in body" do
              expect(adapter).to receive(:send_message!) do |args|
                expect(args[:body_text]).to include("This is my comment")
              end
              subject.start
            end

            it "includes the proposal title in header (truncated to 60 chars)" do
              expect(adapter).to receive(:send_message!) do |args|
                expect(args[:header_text]).to eq("My Test Proposal")
              end
              subject.start
            end
          end

          context "when user sends a second message (re-edit)" do
            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "overwrites the previous comment" do
              # First message
              subject.start
              sender.reload
              expect(sender.current_workflow_options["comment"]).to eq("This is my comment")

              # Second message
              allow(received_message).to receive(:body).and_return("Updated comment")
              message2 = create(:chatbot_message, setting:, sender:)
              workflow2 = described_class.new(adapter:, message: message2, **workflow_options)
              workflow2.start
              sender.reload
              expect(sender.current_workflow_options["comment"]).to eq("Updated comment")
            end
          end

          context "when resource is nil (invalid GID)" do
            let(:workflow_options) { { resource_gid: "gid://decidim/Decidim::Proposals::Proposal/999999" } }

            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "sends ending message with resource_not_found text" do
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  type: :interactive_buttons,
                  body_text: I18n.t("decidim.chatbot.workflows.comments.resource_not_found"),
                  buttons: [hash_including(id: "exit")]
                )
              )
              subject.start
            end
          end
        end

        describe "#process_action_input" do
          before do
            allow(received_message).to receive(:user_text?).and_return(false)
            allow(received_message).to receive(:actionable?).and_return(true)
          end

          context "when 'submit' button is clicked" do
            before do
              allow(received_message).to receive(:button_id).and_return("submit")
              sender.update!(workflow_stack: [
                               {
                                 "class" => "Decidim::Chatbot::Workflows::CommentsWorkflow",
                                 "options" => {
                                   "resource_gid" => proposal.to_global_id.to_s,
                                   "comment" => "My comment"
                                 }
                               }
                             ])
              message.reload
            end

            it "calls mark_as_responding!" do
              expect(adapter).to receive(:mark_as_responding!)
              subject.start
            end

            it "creates a comment on the proposal" do
              expect { subject.start }.to change(Decidim::Comments::Comment, :count).by(1)
            end

            it "creates a comment with correct attributes" do
              subject.start
              comment = Decidim::Comments::Comment.last
              expect(comment.commentable).to eq(proposal)
              expect(comment.author).to eq(sender.user)
              expect(comment.body[sender.locale]).to include("My comment")
              expect(comment.body[sender.locale]).to include(setting.provider.titleize)
            end

            it "sends success message with comment_created text and URL" do
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  type: :interactive_buttons,
                  body_text: a_string_including(I18n.t("decidim.chatbot.workflows.comments.comment_created")),
                  buttons: [hash_including(id: "reset")]
                )
              )
              subject.start
            end
          end

          context "when 'submit' with back_button option" do
            let(:workflow_options) do
              {
                resource_gid: proposal.to_global_id.to_s,
                back_button: { id: "more", title: "View more" }
              }
            end

            before do
              allow(received_message).to receive(:button_id).and_return("submit")
              sender.update!(workflow_stack: [
                               {
                                 "class" => "Decidim::Chatbot::Workflows::CommentsWorkflow",
                                 "options" => {
                                   "resource_gid" => proposal.to_global_id.to_s,
                                   "comment" => "My comment",
                                   "back_button" => { "id" => "more", "title" => "View more" }
                                 }
                               }
                             ])
              message.reload
            end

            it "includes back button before reset button" do
              expect(adapter).to receive(:send_message!) do |args|
                buttons = args[:buttons]
                expect(buttons.first).to include(id: "more", title: "View more")
                expect(buttons.last).to include(id: "reset")
              end
              subject.start
            end
          end

          context "when any other button is clicked (not submit, exit, reset)" do
            before do
              allow(received_message).to receive(:button_id).and_return("unknown_button")
              sender.update!(workflow_stack: [
                               { "class" => "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow", "options" => {} },
                               {
                                 "class" => "Decidim::Chatbot::Workflows::CommentsWorkflow",
                                 "options" => { "resource_gid" => proposal.to_global_id.to_s }
                               }
                             ])
              message.reload
            end

            it "exits the workflow (pops from stack)" do
              subject.start
              sender.reload
              expect(sender.workflow_stack.length).to eq(1)
              expect(sender.workflow_stack.last["class"]).to eq("Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow")
            end
          end

          context "when resource is nil on action" do
            let(:workflow_options) { { resource_gid: "gid://decidim/Decidim::Proposals::Proposal/999999" } }

            before do
              allow(received_message).to receive(:button_id).and_return("submit")
            end

            it "sends ending message" do
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  type: :interactive_buttons,
                  body_text: I18n.t("decidim.chatbot.workflows.comments.resource_not_found")
                )
              )
              subject.start
            end
          end
        end

        describe "edge cases" do
          context "with long proposal title in header" do
            let!(:proposal) do
              create(:proposal,
                     component: proposals_component,
                     title: { en: "A" * 100 },
                     published_at: Time.current)
            end

            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "truncates header to 60 characters" do
              expect(adapter).to receive(:send_message!) do |args|
                expect(args[:header_text].length).to be <= 60
              end
              subject.start
            end
          end
        end
      end
    end
  end
end
