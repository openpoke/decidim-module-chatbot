# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe WebhooksController do
    routes { Decidim::Chatbot::Engine.routes }

    let(:organization) { create(:organization) }
    let!(:setting) { create(:chatbot_setting, organization:, provider:) }
    let(:provider) { "whatsapp" }
    let(:verify_token) { "test-verify-token" }

    before do
      request.env["decidim.current_organization"] = organization
      allow(Decidim::Chatbot).to receive(:whatsapp_config).and_return({
                                                                        verify_token:,
                                                                        access_token: "test-access-token",
                                                                        graph_api_url: "https://graph.facebook.com/v24.0/"
                                                                      })
    end

    describe "before_action" do
      context "with unsupported provider" do
        let(:provider) { "unsupported" }

        it "returns bad request for GET request" do
          get :verify, params: { provider: }
          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body).to eq({ "error" => "Provider [unsupported] not supported" })
        end

        it "returns bad request for POST request" do
          post :receive, params: { provider: }
          expect(response).to have_http_status(:bad_request)
        end
      end

      context "when setting does not exist" do
        before { setting.destroy }

        it "returns bad request" do
          get :verify, params: { provider: "whatsapp" }
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    describe "GET #verify" do
      context "with valid verification request" do
        let(:verify_params) do
          {
            :provider => provider,
            "hub.mode" => "subscribe",
            "hub.verify_token" => verify_token,
            "hub.challenge" => "test-challenge-123"
          }
        end

        it "returns the challenge" do
          get :verify, params: verify_params
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq("test-challenge-123")
        end
      end

      context "with invalid verify token" do
        let(:verify_params) do
          {
            :provider => provider,
            "hub.mode" => "subscribe",
            "hub.verify_token" => "invalid-token",
            "hub.challenge" => "test-challenge-123"
          }
        end

        it "returns forbidden" do
          get :verify, params: verify_params
          expect(response).to have_http_status(:forbidden)
        end
      end

      context "with invalid mode" do
        let(:verify_params) do
          {
            :provider => provider,
            "hub.mode" => "invalid",
            "hub.verify_token" => verify_token,
            "hub.challenge" => "test-challenge-123"
          }
        end

        it "returns forbidden" do
          get :verify, params: verify_params
          expect(response).to have_http_status(:forbidden)
        end
      end

      context "without hub parameters" do
        it "returns forbidden" do
          get :verify, params: { provider: }
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    describe "POST #receive" do
      let(:whatsapp_payload) do
        JSON.parse(file_fixture("whatsapp_received_user.json").read)
      end

      let(:status_payload) do
        JSON.parse(file_fixture("whatsapp_received_status_delivered.json").read)
      end

      let(:adapter_instance) do
        instance_double(
          Decidim::Chatbot::Providers::Whatsapp::Adapter,
          received_message: instance_double(
            Decidim::Chatbot::Providers::Whatsapp::MessageNormalizer,
            from: "34685173326",
            from_name: "Ivan",
            from_metadata: {},
            from_locale: nil,
            message_id: "wamid.HBgLMzQ2ODUxNzMzMjYVAgASGBYzRUIwMThFMjdEQzMwMkQ0REZCQ0M1AA==",
            chat_id: "818813757760148",
            type: "text",
            message_data: { "body" => "this is a message" },
            user_text?: true,
            actionable?: false,
            acknowledgeable?: true
          )
        )
      end

      let(:workflow_instance) { instance_double(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow) }

      before do
        setting.update!(config: { "enabled" => true })
        allow(Decidim::Chatbot::Providers::Whatsapp::Adapter).to receive(:new).and_return(adapter_instance)
        allow(adapter_instance).to receive(:send!)
        allow(adapter_instance).to receive(:mark_as_read!)
        allow(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow).to receive(:new).and_return(workflow_instance)
        allow(workflow_instance).to receive(:start)
      end

      it "processes the webhook and responds with 200 OK" do
        post :receive, params: { provider: }.merge(whatsapp_payload)
        expect(response).to have_http_status(:ok)
      end

      context "with a valid user message" do
        it "creates a sender" do
          expect do
            post :receive, params: { provider: }.merge(whatsapp_payload)
          end.to change(Sender, :count).by(1)
        end

        it "creates a message" do
          expect do
            post :receive, params: { provider: }.merge(whatsapp_payload)
          end.to change(Message, :count).by(1)
        end

        it "sets sender attributes correctly" do
          post :receive, params: { provider: }.merge(whatsapp_payload)

          sender = Sender.last
          expect(sender.from).to eq("34685173326")
          expect(sender.name).to eq("Ivan")
          expect(sender.setting).to eq(setting)
        end

        it "sets message attributes correctly" do
          post :receive, params: { provider: }.merge(whatsapp_payload)

          message = Message.last
          expect(message.message_type).to eq("text")
          expect(message.chat_id).to eq("818813757760148")
        end
      end

      context "with a status message (no user message)" do
        let(:adapter_instance) do
          instance_double(
            Decidim::Chatbot::Providers::Whatsapp::Adapter,
            received_message: instance_double(
              Decidim::Chatbot::Providers::Whatsapp::MessageNormalizer,
              from: nil,
              from_name: nil,
              from_metadata: nil,
              from_locale: nil,
              message_id: nil,
              chat_id: nil,
              type: nil,
              message_data: nil,
              user_text?: false,
              actionable?: false,
              acknowledgeable?: false
            )
          )
        end

        it "does not create a sender" do
          expect do
            post :receive, params: { provider: }.merge(status_payload)
          end.not_to change(Sender, :count)
        end

        it "does not create a message" do
          expect do
            post :receive, params: { provider: }.merge(status_payload)
          end.not_to change(Message, :count)
        end

        it "still responds with 200 OK" do
          post :receive, params: { provider: }.merge(status_payload)
          expect(response).to have_http_status(:ok)
        end
      end

      context "with existing sender" do
        let!(:existing_sender) { create(:chatbot_sender, setting:, from: "34685173326") }

        it "does not create a new sender" do
          expect do
            post :receive, params: { provider: }.merge(whatsapp_payload)
          end.not_to change(Sender, :count)
        end

        it "creates a message linked to existing sender" do
          post :receive, params: { provider: }.merge(whatsapp_payload)

          message = Message.last
          expect(message.sender).to eq(existing_sender)
        end
      end

      context "with existing message (duplicate message_id)" do
        let!(:existing_sender) { create(:chatbot_sender, setting:, from: "34685173326") }
        let!(:existing_message) do
          create(:chatbot_message,
                 setting:,
                 sender: existing_sender,
                 message_id: "wamid.HBgLMzQ2ODUxNzMzMjYVAgASGBYzRUIwMThFMjdEQzMwMkQ0REZCQ0M1AA==")
        end

        it "does not create a new message" do
          expect do
            post :receive, params: { provider: }.merge(whatsapp_payload)
          end.not_to change(Message, :count)
        end
      end

      context "when workflow raises an error" do
        before do
          allow(workflow_instance).to receive(:start).and_raise(StandardError.new("Test error"))
        end

        it "logs the error and returns 200 OK" do
          allow(Rails.logger).to receive(:error)
          post :receive, params: { provider: }.merge(whatsapp_payload)
          expect(response).to have_http_status(:ok)
          expect(Rails.logger).to have_received(:error).with(/error processing webhook/i)
        end
      end

      context "with empty payload" do
        it "responds with 200 OK" do
          post :receive, params: { provider:, entry: [] }
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
