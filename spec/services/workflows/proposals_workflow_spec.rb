# frozen_string_literal: true

require "spec_helper"
require "decidim/proposals/test/factories"

module Decidim
  module Chatbot
    module Workflows
      describe ProposalsWorkflow do
        subject { described_class.new(adapter:, message:, **workflow_options) }

        let(:organization) { create(:organization) }
        let!(:participatory_process) { create(:participatory_process, :with_steps, organization:) }
        let!(:proposals_component) { create(:proposal_component, participatory_space: participatory_process) }
        let(:setting_config) do
          {
            participatory_space_gid: participatory_process.to_global_id.to_s,
            component_id: proposals_component.id
          }
        end
        let(:workflow_options) { { component_id: proposals_component.id } }
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
            button_id: nil
          )
        end

        before do
          allow(adapter).to receive(:received_message).and_return(received_message)
          allow(adapter).to receive(:mark_as_read!)
          allow(adapter).to receive(:mark_as_responding!)
          allow(adapter).to receive(:send_message!)
          # Stub sleep to speed up tests
          allow(subject).to receive(:sleep)
        end

        describe "#process_user_input" do
          context "when there are no proposals" do
            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "sends ending with no_proposals text" do
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  type: :interactive_buttons,
                  body_text: I18n.t("decidim.chatbot.workflows.proposals.no_proposals"),
                  buttons: [{ id: "exit", title: I18n.t("decidim.chatbot.workflows.base.buttons.exit") }]
                )
              )
              subject.start
            end
          end

          context "when there are proposals but fewer than per_page" do
            let!(:proposals) do
              create_list(:proposal, 3, :accepted, component: proposals_component, published_at: Time.current)
            end

            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            # With 3 proposals and per_page=10, remaining_proposals_count = 3 - (10*1) = -7 (negative)
            # So the guard condition triggers send_ending directly (no carousel sent)
            it "sends ending with no_more_proposals text" do
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  type: :interactive_buttons,
                  body_text: I18n.t("decidim.chatbot.workflows.proposals.no_more_proposals")
                )
              )
              subject.start
            end
          end

          def proposals
            @proposals ||= begin
              base = Decidim::Proposals::Proposal
                     .where(decidim_component_id: component.id)
                     .published
                     .only_amendables

              base.left_joins(:proposal_state)
                  .where(
                    "decidim_proposals_proposal_states.token != 'rejected' " \
                    "OR decidim_proposals_proposal_states.token IS NULL"
                  )
            end
          end

          context "when there are exactly per_page proposals" do
            let!(:proposals) do
              create_list(:proposal, 10, :evaluating, component: proposals_component, published_at: Time.current)
            end

            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            # With 10 proposals and per_page=10: remaining = 10 - (10*1) = 0, not negative
            # So it enters the main flow: mark_as_responding, send_cards, send_ending
            it "sends carousel cards then ending" do
              expect(adapter).to receive(:send_message!).with(hash_including(type: :interactive_carousel)).ordered
              expect(adapter).to receive(:send_message!).with(hash_including(type: :interactive_buttons)).ordered
              subject.start
            end

            it "marks as responding" do
              expect(adapter).to receive(:mark_as_responding!)
              subject.start
            end

            it "updates page in current_workflow_options" do
              subject.start
              sender.reload
              expect(sender.current_workflow_options["page"]).to eq(2)
            end
          end

          context "when there are more than per_page proposals" do
            let!(:proposals) do
              # Need > 2*per_page proposals so remaining_proposals_count > per_page triggers send_continuation
              create_list(:proposal, 21, :accepted, component: proposals_component, published_at: Time.current)
            end
            let!(:rejected_proposals) do
              create_list(:proposal, 5, :rejected, component: proposals_component, published_at: Time.current)
            end

            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            # With 21 proposals and per_page=10: remaining = 21 - (10*1) = 11 > 10
            # Main flow: mark_as_responding, send_cards (10 cards), send_continuation (11 remaining)
            it "sends carousel then continuation with remaining count and delay" do
              expect(adapter).to receive(:send_message!).with(hash_including(type: :interactive_carousel)).ordered
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  type: :interactive_buttons,
                  delay: 3,
                  body_text: I18n.t("decidim.chatbot.workflows.proposals.remaining_proposals", count: 11),
                  buttons: [
                    { id: "more", title: I18n.t("decidim.chatbot.workflows.proposals.buttons.more") },
                    { id: "exit", title: I18n.t("decidim.chatbot.workflows.base.buttons.exit") }
                  ]
                )
              ).ordered
              subject.start
            end
          end
        end

        describe "carousel card format" do
          let!(:proposal) do
            create(:proposal, :accepted, component: proposals_component, title: { en: "My Proposal Title" }, published_at: Time.current)
          end
          # Need at least per_page proposals to avoid negative remaining guard
          let!(:extra_proposals) { create_list(:proposal, 9, :accepted, component: proposals_component, published_at: Time.current) }

          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "builds card with correct structure" do
            expect(adapter).to receive(:send_message!) do |args|
              next unless args.is_a?(Hash) && args[:type] == :interactive_carousel

              card = args[:cards].find { |c| c[:id] == proposal.id }
              expect(card).to be_present
              expect(card[:title]).to eq(I18n.t("decidim.chatbot.workflows.proposals.buttons.view_proposal"))
              expect(card[:body_text]).to be_present
              expect(card[:image_url]).to be_present
            end.at_least(:once)
            subject.start
          end

          context "when proposal has no photo" do
            it "uses placeholder image URL" do
              expect(adapter).to receive(:send_message!) do |args|
                next unless args.is_a?(Hash) && args[:type] == :interactive_carousel

                card = args[:cards].first
                expect(card[:image_url]).to include("chatbot-card-placeholder")
              end.at_least(:once)
              subject.start
            end
          end
        end

        describe "body text" do
          let!(:proposals) { create_list(:proposal, 10, :accepted, component: proposals_component, published_at: Time.current) }

          before do
            allow(received_message).to receive(:user_text?).and_return(true)
            allow(received_message).to receive(:actionable?).and_return(false)
          end

          it "includes component name in bold" do
            expect(adapter).to receive(:send_message!) do |args|
              next unless args.is_a?(Hash) && args[:type] == :interactive_carousel

              expect(args[:body_text]).to include("*")
            end.at_least(:once)
            subject.start
          end
        end

        describe "#process_action_input" do
          let!(:proposals) { create_list(:proposal, 12, :accepted, component: proposals_component, published_at: Time.current) }

          before do
            allow(received_message).to receive(:user_text?).and_return(false)
            allow(received_message).to receive(:actionable?).and_return(true)
          end

          context "when 'more' button is clicked" do
            before do
              allow(received_message).to receive(:button_id).and_return("more")
            end

            it "calls process_user_input for next page" do
              subject.start
              sender.reload
              expect(sender.current_workflow_options["page"]).to eq(2)
            end
          end

          context "when 'exit' button is clicked" do
            before do
              allow(received_message).to receive(:button_id).and_return("exit")
              sender.update!(workflow_stack: [
                               { "class" => "Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow", "options" => {} },
                               { "class" => "Decidim::Chatbot::Workflows::ProposalsWorkflow",
                                 "options" => { "component_id" => proposals_component.id } }
                             ])
              message.reload
            end

            it "exits the workflow by popping from stack" do
              subject.start
              sender.reload
              expect(sender.workflow_stack.length).to eq(1)
              expect(sender.workflow_stack.last["class"]).to eq("Decidim::Chatbot::Workflows::SingleParticipatorySpaceWorkflow")
            end
          end

          context "when proposal not found (invalid button_id)" do
            before do
              allow(received_message).to receive(:button_id).and_return("99999999")
            end

            it "sends unprocessable_input message" do
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  type: :interactive_buttons,
                  body_text: I18n.t("decidim.chatbot.workflows.base.unprocessable_input")
                )
              )
              subject.start
            end
          end

          context "when a proposal ID is clicked" do
            let(:clicked_proposal) { proposals.first }

            before do
              allow(received_message).to receive(:button_id).and_return(clicked_proposal.id.to_s)
            end

            it "marks as responding" do
              expect(adapter).to receive(:mark_as_responding!)
              subject.start
            end

            it "sends proposal details with comment button" do
              expect(adapter).to receive(:send_message!).with(
                hash_including(
                  type: :interactive_buttons,
                  buttons: [hash_including(id: "comment-#{clicked_proposal.id}")]
                )
              )
              subject.start
            end
          end

          context "when a comment button is clicked" do
            let(:clicked_proposal) { proposals.first }
            let(:comments_workflow_instance) { instance_double(CommentsWorkflow) }

            before do
              allow(received_message).to receive(:button_id).and_return("comment-#{clicked_proposal.id}")
              allow(CommentsWorkflow).to receive(:new).and_return(comments_workflow_instance)
              allow(comments_workflow_instance).to receive(:start)
            end

            it "marks as responding" do
              expect(adapter).to receive(:mark_as_responding!)
              subject.start
            end

            it "delegates to CommentsWorkflow with proposal_id" do
              expect(comments_workflow_instance).to receive(:start).with(true)
              subject.start
            end

            it "pushes CommentsWorkflow to the stack with resource_gid and back_button" do
              subject.start
              sender.reload
              expect(sender.workflow_stack.last["class"]).to eq("Decidim::Chatbot::Workflows::CommentsWorkflow")
              expect(sender.workflow_stack.last["options"]["resource_gid"]).to eq(clicked_proposal.to_global_id.to_s)
              expect(sender.workflow_stack.last["options"]["back_button"]).to be_present
            end
          end
        end
      end
    end
  end
end
