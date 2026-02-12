# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Chatbot
    describe SendMessageJob do
      let(:message_body) { { "messaging_product" => "whatsapp", "to" => "123456", "type" => "text", "text" => { "body" => "Hello" } } }
      let(:adapter_class_name) { "Decidim::Chatbot::Providers::Whatsapp::Adapter" }
      let(:params) { { "key" => "value" } }
      let(:adapter_instance) { instance_double(Providers::Whatsapp::Adapter) }

      before do
        allow(Providers::Whatsapp::Adapter).to receive(:new).with(params:).and_return(adapter_instance)
        allow(adapter_instance).to receive(:send!)
      end

      describe "#perform" do
        it "instantiates the adapter from the class name" do
          expect(Providers::Whatsapp::Adapter).to receive(:new).with(params:)
          described_class.perform_now(message_body, adapter_class_name, params)
        end

        it "calls send! with the message body" do
          expect(adapter_instance).to receive(:send!).with(message_body)
          described_class.perform_now(message_body, adapter_class_name, params)
        end
      end

      describe "queue" do
        it "uses the default queue" do
          expect(described_class.new.queue_name).to eq("default")
        end
      end

      describe "enqueuing with delay" do
        it "enqueues with specified wait time" do
          expect do
            described_class.set(wait: 3).perform_later(message_body, adapter_class_name, params)
          end.to have_enqueued_job(described_class).with(message_body, adapter_class_name, params)
        end
      end
    end
  end
end
