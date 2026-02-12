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
            from: "34123456789",
            from_name: "John Doe",
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
        setting.update!(enabled: true)
        allow(Decidim::Chatbot::Providers::Whatsapp::Adapter).to receive(:new).and_return(adapter_instance)
        allow(adapter_instance).to receive(:send!)
        allow(adapter_instance).to receive(:send_message!)
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
          expect(sender.from).to eq("34123456789")
          expect(sender.name).to eq("John Doe")
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
              acknowledgeable?: false,
              json: "{}"
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
        let!(:existing_sender) { create(:chatbot_sender, setting:, from: "34123456789") }

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
        let!(:existing_sender) { create(:chatbot_sender, setting:, from: "34123456789") }
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

    describe "#check_enabled" do
      let(:disabled_adapter) do
        instance_double(
          Decidim::Chatbot::Providers::Whatsapp::Adapter,
          received_message: instance_double(
            Decidim::Chatbot::Providers::Whatsapp::MessageNormalizer,
            from: nil, from_name: nil, from_metadata: nil, from_locale: nil,
            message_id: nil, chat_id: nil, type: nil, message_data: nil,
            user_text?: false, actionable?: false, acknowledgeable?: false
          )
        ).tap do |a|
          allow(a).to receive(:send_message!)
        end
      end

      before do
        setting.update!(enabled: false)
        allow(Decidim::Chatbot::Providers::Whatsapp::Adapter).to receive(:new).and_return(disabled_adapter)
      end

      context "when setting is disabled" do
        it "returns head :ok without creating sender or message" do
          post :receive, params: { provider: "whatsapp", entry: [] }
          expect(response).to have_http_status(:ok)
          expect(Sender.count).to eq(0)
        end
      end

      context "when deactivated_message is configured" do
        before do
          allow(Decidim::Chatbot).to receive(:deactivated_message).and_return("decidim.chatbot.messages.deactivated")
        end

        it "sends the deactivated message via adapter" do
          expect(disabled_adapter).to receive(:send_message!).with(
            I18n.t("decidim.chatbot.messages.deactivated")
          )
          post :receive, params: { provider: "whatsapp", entry: [] }
        end
      end

      context "when deactivated_message is nil" do
        before do
          allow(Decidim::Chatbot).to receive(:deactivated_message).and_return(nil)
        end

        it "does not send any message" do
          expect(disabled_adapter).not_to receive(:send_message!)
          post :receive, params: { provider: "whatsapp", entry: [] }
        end

        it "returns head :ok" do
          post :receive, params: { provider: "whatsapp", entry: [] }
          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe "#clear_stale_workflows_for_sender" do
      let(:whatsapp_payload) do
        JSON.parse(file_fixture("whatsapp_received_user.json").read)
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
            message_data: { "body" => "hello" },
            user_text?: true,
            actionable?: false,
            acknowledgeable?: true
          )
        )
      end

      let(:workflow_instance) { instance_double(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow) }

      before do
        setting.update!(enabled: true)
        allow(Decidim::Chatbot::Providers::Whatsapp::Adapter).to receive(:new).and_return(adapter_instance)
        allow(adapter_instance).to receive(:send!)
        allow(adapter_instance).to receive(:send_message!)
        allow(adapter_instance).to receive(:mark_as_read!)
        allow(Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow).to receive(:new).and_return(workflow_instance)
        allow(workflow_instance).to receive(:start)
      end

      context "when sender has stale workflows" do
        let!(:stale_sender) do
          create(:chatbot_sender, :with_workflow, setting:, from: "34685173326").tap do |s|
            s.update_column(:updated_at, 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
          end
        end

        it "clears the workflow stack" do
          post :receive, params: { provider: }.merge(whatsapp_payload)
          stale_sender.reload
          expect(stale_sender.workflow_stack).to eq([])
        end

        it "sends stale_cleared message" do
          expect(adapter_instance).to receive(:send_message!).with(
            I18n.t("decidim.chatbot.messages.stale_cleared")
          )
          post :receive, params: { provider: }.merge(whatsapp_payload)
        end
      end

      context "when sender was recently active" do
        let!(:recent_sender) do
          create(:chatbot_sender, :with_workflow, setting:, from: "34685173326")
        end

        it "does not clear the workflow stack" do
          post :receive, params: { provider: }.merge(whatsapp_payload)
          recent_sender.reload
          expect(recent_sender.workflow_stack).not_to eq([])
        end
      end
    end
  end
end
