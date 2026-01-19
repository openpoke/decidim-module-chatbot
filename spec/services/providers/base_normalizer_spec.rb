# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Providers
      describe BaseNormalizer do
        subject { described_class.new }

        describe "attributes" do
          it "has message_data accessor" do
            subject.message_data = { "test" => "data" }
            expect(subject.message_data).to eq({ "test" => "data" })
          end

          it "has from accessor" do
            subject.from = "123456789"
            expect(subject.from).to eq("123456789")
          end

          it "has from_name accessor" do
            subject.from_name = "Test User"
            expect(subject.from_name).to eq("Test User")
          end

          it "has from_locale accessor" do
            subject.from_locale = "es"
            expect(subject.from_locale).to eq("es")
          end

          it "has from_metadata accessor" do
            subject.from_metadata = { "key" => "value" }
            expect(subject.from_metadata).to eq({ "key" => "value" })
          end

          it "has message_id accessor" do
            subject.message_id = "msg-123"
            expect(subject.message_id).to eq("msg-123")
          end

          it "has chat_id accessor" do
            subject.chat_id = "chat-123"
            expect(subject.chat_id).to eq("chat-123")
          end

          it "has body accessor" do
            subject.body = "Hello world"
            expect(subject.body).to eq("Hello world")
          end

          it "has to accessor" do
            subject.to = "987654321"
            expect(subject.to).to eq("987654321")
          end

          it "has type accessor" do
            subject.type = "text"
            expect(subject.type).to eq("text")
          end

          it "has button_id accessor" do
            subject.button_id = "btn-1"
            expect(subject.button_id).to eq("btn-1")
          end
        end

        describe "#acknowledgeable?" do
          context "when from and message_id are present" do
            before do
              subject.from = "123456"
              subject.message_id = "msg-123"
            end

            it "returns true" do
              expect(subject.acknowledgeable?).to be true
            end
          end

          context "when from is blank" do
            before do
              subject.from = nil
              subject.message_id = "msg-123"
            end

            it "returns false" do
              expect(subject.acknowledgeable?).to be false
            end
          end

          context "when message_id is blank" do
            before do
              subject.from = "123456"
              subject.message_id = nil
            end

            it "returns false" do
              expect(subject.acknowledgeable?).to be false
            end
          end
        end

        describe "#user_text?" do
          context "when from, body are present and button_id is nil" do
            before do
              subject.from = "123456"
              subject.body = "Hello"
              subject.button_id = nil
            end

            it "returns true" do
              expect(subject.user_text?).to be true
            end
          end

          context "when from is blank" do
            before do
              subject.from = nil
              subject.body = "Hello"
              subject.button_id = nil
            end

            it "returns false" do
              expect(subject.user_text?).to be false
            end
          end

          context "when body is blank" do
            before do
              subject.from = "123456"
              subject.body = nil
              subject.button_id = nil
            end

            it "returns false" do
              expect(subject.user_text?).to be false
            end
          end

          context "when button_id is present" do
            before do
              subject.from = "123456"
              subject.body = "Hello"
              subject.button_id = "btn-1"
            end

            it "returns false" do
              expect(subject.user_text?).to be false
            end
          end
        end

        describe "#actionable?" do
          context "when from and button_id are present" do
            before do
              subject.from = "123456"
              subject.button_id = "btn-1"
            end

            it "returns true" do
              expect(subject.actionable?).to be true
            end
          end

          context "when from is blank" do
            before do
              subject.from = nil
              subject.button_id = "btn-1"
            end

            it "returns false" do
              expect(subject.actionable?).to be false
            end
          end

          context "when button_id is blank" do
            before do
              subject.from = "123456"
              subject.button_id = nil
            end

            it "returns false" do
              expect(subject.actionable?).to be false
            end
          end
        end
      end
    end
  end
end
