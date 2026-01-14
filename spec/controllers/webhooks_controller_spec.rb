# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe WebhooksController do
    routes { Decidim::Chatbot::Engine.routes }

    let(:organization) { create(:organization) }
    let!(:setting) { create(:chatbot_setting, organization:, provider:) }
    let(:provider) { "whatsapp" }

    before do
      request.env["decidim.current_organization"] = organization
    end

    describe "POST #receive" do
      it "processes the webhook and responds with 200 OK" do
        post :receive, params: { provider: provider }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
