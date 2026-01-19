# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        describe Adapter do
          subject { described_class.new(params:) }

          let(:params) { whatsapp_payload }
          let(:whatsapp_payload) do
            JSON.parse(file_fixture("whatsapp_received_user.json").read)
          end
          let(:verify_token) { "test-verify-token" }
          let(:access_token) { "test-access-token" }
          let(:graph_api_url) { "https://graph.facebook.com/v24.0/" }

          before do
            allow(Decidim::Chatbot).to receive(:whatsapp_config).and_return({
                                                                              verify_token:,
                                                                              access_token:,
                                                                              graph_api_url:
                                                                            })
          end

          describe "#verify!" do
            context "with valid verification request" do
              let(:params) do
                {
                  "hub.mode" => "subscribe",
                  "hub.verify_token" => verify_token,
                  "hub.challenge" => "challenge-123"
                }
              end

              it "returns the challenge" do
                expect(subject.verify!).to eq("challenge-123")
              end
            end

            context "with invalid verify token" do
              let(:params) do
                {
                  "hub.mode" => "subscribe",
                  "hub.verify_token" => "wrong-token",
                  "hub.challenge" => "challenge-123"
                }
              end

              it "returns nil" do
                expect(subject.verify!).to be_nil
              end
            end

            context "with invalid mode" do
              let(:params) do
                {
                  "hub.mode" => "unsubscribe",
                  "hub.verify_token" => verify_token,
                  "hub.challenge" => "challenge-123"
                }
              end

              it "returns nil" do
                expect(subject.verify!).to be_nil
              end
            end

            context "without hub parameters" do
              let(:params) { {} }

              it "returns nil" do
                expect(subject.verify!).to be_nil
              end
            end
          end

          describe "#received_message" do
            it "returns a MessageNormalizer instance" do
              expect(subject.received_message).to be_a(MessageNormalizer)
            end

            it "memoizes the result" do
              first_call = subject.received_message
              second_call = subject.received_message
              expect(first_call).to be(second_call)
            end

            it "extracts the correct from number" do
              expect(subject.received_message.from).to eq("34685173326")
            end

            it "extracts the correct message body" do
              expect(subject.received_message.body).to eq("this is a message")
            end
          end

          describe "#build_message" do
            context "with text type" do
              let(:message) { subject.build_message(to: "123", data: { body: "Hello" }, type: :text) }

              it "returns a Text envelope" do
                expect(message).to be_a(Envelopes::Text)
              end

              it "sets the recipient" do
                expect(message.to).to eq("123")
              end

              it "sets the data" do
                expect(message.data).to eq({ body: "Hello" })
              end
            end

            context "with interactive_buttons type" do
              let(:data) do
                {
                  body_text: "Choose an option",
                  buttons: [{ id: "btn1", title: "Option 1" }]
                }
              end
              let(:message) { subject.build_message(to: "123", data:, type: :interactive_buttons) }

              it "returns an InteractiveButtons envelope" do
                expect(message).to be_a(Envelopes::InteractiveButtons)
              end
            end

            context "with interactive_carousel type" do
              let(:data) do
                {
                  body_text: "Check these options",
                  cards: [{ image_url: "http://example.com/img.jpg", body_text: "Card 1", url: "http://example.com", url_title: "Visit" }]
                }
              end
              let(:message) { subject.build_message(to: "123", data:, type: :interactive_carousel) }

              it "returns an InteractiveCarousel envelope" do
                expect(message).to be_a(Envelopes::InteractiveCarousel)
              end
            end

            context "with read_receipt type" do
              let(:message) { subject.build_message(to: nil, data: { message_id: "msg-123" }, type: :read_receipt) }

              it "returns a ReadReceipt envelope" do
                expect(message).to be_a(Envelopes::ReadReceipt)
              end
            end
          end

          describe "#mark_as_read!" do
            let(:mock_envelope) { instance_double(Envelopes::ReadReceipt) }

            before do
              allow(subject).to receive(:build_message).and_return(mock_envelope)
              allow(subject).to receive(:send!)
            end

            it "builds a read receipt message" do
              expect(subject).to receive(:build_message).with(
                type: :read_receipt,
                data: {
                  message_id: subject.received_message.message_id
                }
              )
              subject.mark_as_read!
            end

            it "sends the read receipt" do
              expect(subject).to receive(:send!).with(mock_envelope)
              subject.mark_as_read!
            end
          end

          describe "#send!" do
            let(:message) { Envelopes::Text.new(to: "123456", data: { body: "Hello" }) }
            let(:response) { instance_double(Faraday::Response, success?: true, status: 200) }

            before do
              allow(Faraday).to receive(:post).and_return(response)
            end

            it "posts to the WhatsApp API" do
              expect(Faraday).to receive(:post).with(
                "#{graph_api_url}873575429163486/messages?access_token=#{access_token}"
              )
              subject.send!(message)
            end

            it "sends JSON content type" do
              expect(Faraday).to receive(:post) do |_url, &block|
                req = double("request", headers: {}, body: nil)
                allow(req).to receive(:headers=)
                allow(req).to receive(:body=)
                block.call(req)
                expect(req).to have_received(:body=).with(message.body.to_json)
                response
              end
              subject.send!(message)
            end

            context "when API returns error" do
              let(:error_response) { instance_double(Faraday::Response, success?: false, status: 401, body: "Unauthorized") }

              before do
                allow(Faraday).to receive(:post).and_return(error_response)
              end

              it "logs the error" do
                expect(Rails.logger).to receive(:error).with(/Error sending Whatsapp message/)
                subject.send!(message)
              end
            end

            context "when Faraday raises an error" do
              before do
                allow(Faraday).to receive(:post).and_raise(Faraday::ConnectionFailed.new("Connection failed"))
              end

              it "logs the error and re-raises" do
                expect(Rails.logger).to receive(:error).with(/Faraday error sending Whatsapp message/)
                expect { subject.send!(message) }.to raise_error(Faraday::ConnectionFailed)
              end
            end
          end
        end
      end
    end
  end
end
