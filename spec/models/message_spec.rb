# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe Message do
    subject { message }

    let(:organization) { create(:organization) }
    let(:setting) { create(:chatbot_setting, organization:) }
    let(:sender) { create(:chatbot_sender, setting:) }
    let(:message) { build(:chatbot_message, setting:, sender:) }

    it { is_expected.to be_valid }

    context "without a setting" do
      let(:message) { build(:chatbot_message, setting: nil, sender:) }

      it { is_expected.not_to be_valid }
    end

    context "without a sender" do
      let(:message) { build(:chatbot_message, setting:, sender: nil) }

      it { is_expected.to be_valid }
    end

    describe "associations" do
      it "belongs to a setting" do
        expect(message.setting).to eq(setting)
      end

      it "belongs to a sender" do
        expect(message.sender).to eq(sender)
      end
    end

    describe "#mark_as_read!" do
      let(:message) { create(:chatbot_message, setting:, sender:, read_at: nil) }

      it "marks the message as read" do
        expect(message.read_at).to be_nil
        message.mark_as_read!
        expect(message.read_at).to be_present
      end

      it "sets read_at to current time" do
        freeze_time do
          message.mark_as_read!
          expect(message.read_at).to eq(Time.current)
        end
      end

      context "when message is already read" do
        let(:original_read_at) { 1.hour.ago }
        let(:message) { create(:chatbot_message, setting:, sender:, read_at: original_read_at) }

        it "updates the read_at timestamp" do
          freeze_time do
            message.mark_as_read!
            expect(message.read_at).to eq(Time.current)
          end
        end
      end
    end

    describe "message types" do
      context "with text type" do
        let(:message) { build(:chatbot_message, setting:, sender:, message_type: "text") }

        it "stores text content" do
          expect(message.content).to include("body")
        end
      end

      context "with interactive type" do
        let(:message) { build(:chatbot_message, :interactive, setting:, sender:) }

        it "stores interactive content" do
          expect(message.message_type).to eq("interactive")
          expect(message.content).to include("button_reply")
        end
      end
    end
  end
end
