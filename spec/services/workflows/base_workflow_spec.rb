# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Workflows
      describe BaseWorkflow do
        subject { described_class.new(adapter:, message:) }

        let(:organization) { create(:organization) }
        let(:setting) { create(:chatbot_setting, organization:) }
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
            acknowledgeable?: true
          )
        end

        before do
          allow(adapter).to receive(:received_message).and_return(received_message)
          allow(adapter).to receive(:mark_as_read!)
          allow(adapter).to receive(:build_message)
          allow(adapter).to receive(:send!)
          allow(adapter).to receive(:send_message!)
        end

        describe "#initialize" do
          it "stores the adapter" do
            expect(subject.adapter).to eq(adapter)
          end

          it "stores the message" do
            expect(subject.message).to eq(message)
          end

          context "with additional options" do
            subject { described_class.new(adapter:, message:, custom_option: "value") }

            it "stores options" do
              expect(subject.options[:custom_option]).to eq("value")
            end
          end
        end

        describe "delegations" do
          it "delegates build_message to adapter" do
            subject.build_message(data: { body: "test" })
            expect(adapter).to have_received(:build_message).with(data: { body: "test" })
          end

          it "delegates received_message to adapter" do
            expect(subject.received_message).to eq(received_message)
          end

          it "delegates setting to message" do
            expect(subject.setting).to eq(setting)
          end

          it "delegates sender to message" do
            expect(subject.sender).to eq(sender)
          end

          it "delegates organization to setting" do
            expect(subject.organization).to eq(organization)
          end

          it "delegates current_workflow to sender" do
            expect(subject.current_workflow).to eq(sender.current_workflow)
          end

          it "delegates parent_workflow to sender" do
            expect(subject.parent_workflow).to eq(sender.parent_workflow)
          end
        end

        describe "#start" do
          context "when received_message is user_text" do
            before do
              allow(received_message).to receive(:user_text?).and_return(true)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "calls mark_as_read" do
              expect { subject.start }.to raise_error(NotImplementedError)
              expect(adapter).to have_received(:mark_as_read!)
            end

            it "calls process_user_input" do
              expect { subject.start }.to raise_error(NotImplementedError)
            end
          end

          context "when received_message is actionable" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(true)
            end

            it "calls mark_as_read" do
              expect { subject.start }.to raise_error(NotImplementedError)
              expect(adapter).to have_received(:mark_as_read!)
            end

            it "calls process_action_input" do
              expect { subject.start }.to raise_error(NotImplementedError)
            end
          end

          context "with force_welcome=true" do
            before do
              allow(received_message).to receive(:user_text?).and_return(false)
              allow(received_message).to receive(:actionable?).and_return(false)
            end

            it "calls process_user_input" do
              expect { subject.start(true) }.to raise_error(NotImplementedError)
            end
          end

          context "when message is not acknowledgeable" do
            before do
              allow(received_message).to receive(:acknowledgeable?).and_return(false)
              allow(received_message).to receive(:user_text?).and_return(true)
            end

            it "does not call mark_as_read on adapter" do
              expect { subject.start }.to raise_error(NotImplementedError)
              expect(adapter).not_to have_received(:mark_as_read!)
            end
          end
        end

        describe "#delegate_workflow" do
          let(:new_workflow_class) { Workflows::ParticipatorySpaceWorkflow }
          let(:new_workflow_instance) { instance_double(new_workflow_class) }

          before do
            allow(new_workflow_class).to receive(:new).and_return(new_workflow_instance)
            allow(new_workflow_instance).to receive(:start)
          end

          it "updates sender's current_workflow_class" do
            subject.send(:delegate_workflow, new_workflow_class)
            sender.reload
            expect(sender.current_workflow_class).to eq(new_workflow_class.name)
          end

          it "updates sender's parent_workflow_class" do
            subject.send(:delegate_workflow, new_workflow_class)
            sender.reload
            expect(sender.parent_workflow_class).to eq(described_class.name)
          end

          it "starts the new workflow with force_welcome=true" do
            expect(new_workflow_instance).to receive(:start).with(true)
            subject.send(:delegate_workflow, new_workflow_class)
          end
        end

        describe "#reset_workflows" do
          it "clears sender's workflow classes" do
            sender.update!(
              current_workflow_class: "SomeWorkflow",
              parent_workflow_class: "ParentWorkflow"
            )

            subject.send(:reset_workflows)
            sender.reload

            expect(sender.current_workflow_class).to be_nil
            expect(sender.parent_workflow_class).to be_nil
          end

          it "sends a reset message" do
            expect(adapter).to receive(:send_message!).with(
              I18n.t("decidim.chatbot.messages.reset_workflows")
            )
            subject.send(:reset_workflows)
          end
        end

        describe "#mark_as_read" do
          context "when message is acknowledgeable" do
            before do
              allow(received_message).to receive(:acknowledgeable?).and_return(true)
            end

            it "calls mark_as_read! on adapter" do
              subject.send(:mark_as_read)
              expect(adapter).to have_received(:mark_as_read!)
            end

            it "marks the message as read" do
              expect { subject.send(:mark_as_read) }.to change { message.reload.read_at }.from(nil)
            end
          end

          context "when message is not acknowledgeable" do
            before do
              allow(received_message).to receive(:acknowledgeable?).and_return(false)
            end

            it "does not call mark_as_read! on adapter" do
              subject.send(:mark_as_read)
              expect(adapter).not_to have_received(:mark_as_read!)
            end
          end

          context "when message is nil" do
            let(:message) { nil }
            let(:workflow) { described_class.new(adapter:, message: nil) }

            before do
              allow(received_message).to receive(:acknowledgeable?).and_return(true)
            end

            it "handles nil message gracefully" do
              expect { workflow.send(:mark_as_read) }.not_to raise_error
            end
          end
        end
      end
    end
  end
end
