# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        describe MessageNormalizer do
          subject { described_class.new(json) }

          describe "with text message" do
            let(:json) { JSON.parse(file_fixture("whatsapp_received_user.json").read) }

            it "extracts the from number" do
              expect(subject.from).to eq("34685173326")
            end

            it "extracts the from name" do
              expect(subject.from_name).to eq("Ivan")
            end

            it "extracts the phone_number_id" do
              expect(subject.phone_number_id).to eq("873575429163486")
            end

            it "extracts the display phone number as to" do
              expect(subject.to).to eq("15551918371")
            end

            it "extracts the chat_id" do
              expect(subject.chat_id).to eq("818813757760148")
            end

            it "extracts the message_id" do
              expect(subject.message_id).to eq("wamid.HBgLMzQ2ODUxNzMzMjYVAgASGBYzRUIwMThFMjdEQzMwMkQ0REZCQ0M1AA==")
            end

            it "extracts the body" do
              expect(subject.body).to eq("this is a message")
            end

            it "extracts the type" do
              expect(subject.type).to eq("text")
            end

            it "has no button_id" do
              expect(subject.button_id).to be_nil
            end

            describe "#user_text?" do
              it "returns true for text messages" do
                expect(subject.user_text?).to be true
              end
            end

            describe "#acknowledgeable?" do
              it "returns true" do
                expect(subject.acknowledgeable?).to be true
              end
            end

            describe "#actionable?" do
              it "returns false" do
                expect(subject.actionable?).to be false
              end
            end
          end

          describe "with status message (delivered)" do
            let(:json) { JSON.parse(file_fixture("whatsapp_received_status_delivered.json").read) }

            it "does not extract from (contacts not present)" do
              expect(subject.from).to be_nil
            end

            it "extracts phone_number_id" do
              expect(subject.phone_number_id).to eq("873575429163486")
            end

            it "has no message_id" do
              expect(subject.message_id).to be_nil
            end

            it "has no body" do
              expect(subject.body).to be_nil
            end

            describe "#user_text?" do
              it "returns false" do
                expect(subject.user_text?).to be false
              end
            end

            describe "#acknowledgeable?" do
              it "returns false" do
                expect(subject.acknowledgeable?).to be false
              end
            end

            describe "#actionable?" do
              it "returns false" do
                expect(subject.actionable?).to be false
              end
            end
          end

          describe "with interactive button reply" do
            let(:json) do
              {
                "object" => "whatsapp_business_account",
                "entry" => [
                  {
                    "id" => "818813757760148",
                    "changes" => [
                      {
                        "value" => {
                          "messaging_product" => "whatsapp",
                          "metadata" => {
                            "display_phone_number" => "15551918371",
                            "phone_number_id" => "873575429163486"
                          },
                          "contacts" => [
                            {
                              "profile" => { "name" => "Test User" },
                              "wa_id" => "123456789"
                            }
                          ],
                          "messages" => [
                            {
                              "from" => "123456789",
                              "id" => "wamid.test123",
                              "timestamp" => "1234567890",
                              "type" => "interactive",
                              "interactive" => {
                                "type" => "button_reply",
                                "button_reply" => {
                                  "id" => "start",
                                  "title" => "Start"
                                }
                              }
                            }
                          ]
                        },
                        "field" => "messages"
                      }
                    ]
                  }
                ]
              }
            end

            it "extracts the from number" do
              expect(subject.from).to eq("123456789")
            end

            it "extracts the button_id" do
              expect(subject.button_id).to eq("start")
            end

            it "extracts the body from button_reply title" do
              expect(subject.body).to eq("Start")
            end

            it "extracts the type as interactive" do
              expect(subject.type).to eq("interactive")
            end

            describe "#user_text?" do
              it "returns false for interactive messages" do
                expect(subject.user_text?).to be false
              end
            end

            describe "#actionable?" do
              it "returns true" do
                expect(subject.actionable?).to be true
              end
            end
          end

          describe "with interactive list reply" do
            let(:json) do
              {
                "object" => "whatsapp_business_account",
                "entry" => [
                  {
                    "id" => "818813757760148",
                    "changes" => [
                      {
                        "value" => {
                          "messaging_product" => "whatsapp",
                          "metadata" => {
                            "display_phone_number" => "15551918371",
                            "phone_number_id" => "873575429163486"
                          },
                          "contacts" => [
                            {
                              "profile" => { "name" => "Test User" },
                              "wa_id" => "123456789"
                            }
                          ],
                          "messages" => [
                            {
                              "from" => "123456789",
                              "id" => "wamid.test123",
                              "timestamp" => "1234567890",
                              "type" => "interactive",
                              "interactive" => {
                                "type" => "list_reply",
                                "list_reply" => {
                                  "id" => "option-1",
                                  "title" => "Option 1"
                                }
                              }
                            }
                          ]
                        },
                        "field" => "messages"
                      }
                    ]
                  }
                ]
              }
            end

            it "extracts the button_id from list_reply" do
              expect(subject.button_id).to eq("option-1")
            end

            it "extracts the body from list_reply title" do
              expect(subject.body).to eq("Option 1")
            end

            describe "#actionable?" do
              it "returns true" do
                expect(subject.actionable?).to be true
              end
            end
          end

          describe "with empty payload" do
            let(:json) do
              {
                "entry" => [
                  {
                    "id" => "818813757760148",
                    "changes" => [
                      {
                        "value" => {
                          "messaging_product" => "whatsapp",
                          "metadata" => {
                            "display_phone_number" => "15551918371",
                            "phone_number_id" => "873575429163486"
                          }
                        },
                        "field" => "messages"
                      }
                    ]
                  }
                ]
              }
            end

            it "handles empty messages gracefully" do
              expect(subject.from).to be_nil
              expect(subject.message_id).to be_nil
              expect(subject.body).to be_nil
            end

            describe "#user_text?" do
              it "returns false" do
                expect(subject.user_text?).to be false
              end
            end

            describe "#acknowledgeable?" do
              it "returns false" do
                expect(subject.acknowledgeable?).to be false
              end
            end
          end

          describe "#json" do
            let(:json) { JSON.parse(file_fixture("whatsapp_received_user.json").read) }

            it "stores the original json" do
              expect(subject.json).to eq(json)
            end
          end

          describe "#message_data" do
            let(:json) { JSON.parse(file_fixture("whatsapp_received_user.json").read) }

            it "returns the value object from the payload" do
              expect(subject.message_data).to be_a(Hash)
              expect(subject.message_data["messaging_product"]).to eq("whatsapp")
            end

            it "contains the metadata" do
              expect(subject.message_data["metadata"]["phone_number_id"]).to eq("873575429163486")
            end

            it "contains the contacts" do
              expect(subject.message_data["contacts"]).to be_present
              expect(subject.message_data.dig("contacts", 0, "wa_id")).to eq("34685173326")
            end

            it "contains the messages" do
              expect(subject.message_data["messages"]).to be_present
              expect(subject.message_data.dig("messages", 0, "type")).to eq("text")
            end
          end

          describe "#from_metadata" do
            let(:json) { JSON.parse(file_fixture("whatsapp_received_user.json").read) }

            it "returns nil by default (not set by WhatsApp normalizer)" do
              expect(subject.from_metadata).to be_nil
            end
          end

          describe "#from_locale" do
            let(:json) { JSON.parse(file_fixture("whatsapp_received_user.json").read) }

            it "returns nil by default (not set by WhatsApp normalizer)" do
              expect(subject.from_locale).to be_nil
            end
          end
        end
      end
    end
  end
end
