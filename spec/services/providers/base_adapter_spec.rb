# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    module Providers
      describe BaseAdapter do
        subject { described_class.new(params:) }

        let(:params) { { "key" => "value" } }

        describe "#initialize" do
          it "stores params" do
            expect(subject.params).to eq(params)
          end

          it "duplicates the params to avoid mutation" do
            adapter = described_class.new(params:)
            adapter.params["new_key"] = "new_value"
            expect(params).not_to have_key("new_key")
          end
        end

        describe "#received_message" do
          it "raises NotImplementedError" do
            expect { subject.received_message }.to raise_error(NotImplementedError)
          end
        end

        describe "#build_message" do
          it "raises NotImplementedError" do
            expect { subject.build_message(data: {}, to: "123", type: :text) }.to raise_error(NotImplementedError)
          end
        end

        describe "#verify!" do
          it "returns a not_implemented status by default" do
            expect(subject.verify!).to eq({ status: :not_implemented })
          end
        end

        describe "#mark_as_read!" do
          it "returns nil by default" do
            expect(subject.mark_as_read!).to be_nil
          end
        end

        describe "#send_message!" do
          let(:mock_message) { double("message", body: { to: "123456", text: { body: "Hello world" } }) }
          let(:received_message) { double("received_message", from: "123456") }

          before do
            allow(subject).to receive(:received_message).and_return(received_message)
            allow(subject).to receive(:build_message).and_return(mock_message)
          end

          it "builds a text message with the provided text" do
            expect(subject).to receive(:build_message).with(
              to: "123456",
              data: { body: "Hello world" },
              type: :text
            )
            subject.send_message!("Hello world")
          end

          it "enqueues SendMessageJob" do
            expect(Decidim::Chatbot::SendMessageJob).to receive(:set).with(wait: 0).and_call_original
            subject.send_message!("Hello world")
          end

          it "passes adapter class name and params to the job" do
            job_double = double("job")
            allow(Decidim::Chatbot::SendMessageJob).to receive(:set).and_return(job_double)
            expect(job_double).to receive(:perform_later).with(
              anything,
              "Decidim::Chatbot::Providers::BaseAdapter",
              params.as_json
            )
            subject.send_message!("Hello world")
          end

          context "with custom delay" do
            it "enqueues job with specified delay" do
              expect(Decidim::Chatbot::SendMessageJob).to receive(:set).with(wait: 5).and_call_original
              subject.send_message!(body: "test", delay: 5)
            end
          end

          context "with hash input" do
            it "extracts type, to, and delay from data" do
              expect(subject).to receive(:build_message).with(
                to: "custom_to",
                data: { body_text: "test" },
                type: :interactive_buttons
              )
              subject.send_message!(type: :interactive_buttons, to: "custom_to", body_text: "test")
            end
          end
        end

        describe "#send!" do
          it "raises NotImplementedError" do
            expect { subject.send!("message") }.to raise_error(NotImplementedError)
          end
        end
      end
    end
  end
end
