# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Chatbot Webhooks", type: :request do
  describe "GET /chatbot/webhooks/whatsapp" do
    around do |example|
      original = ENV["WHATSAPP_VERIFY_TOKEN"]
      ENV["WHATSAPP_VERIFY_TOKEN"] = "test-token"
      example.run
      ENV["WHATSAPP_VERIFY_TOKEN"] = original
    end

    it "returns the challenge when token matches" do
      get "/chatbot/webhooks/whatsapp", params: {
        "hub.mode" => "subscribe",
        "hub.verify_token" => "test-token",
        "hub.challenge" => "abc123"
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("abc123")
    end

    it "returns 403 when token mismatches" do
      get "/chatbot/webhooks/whatsapp", params: {
        "hub.mode" => "subscribe",
        "hub.verify_token" => "wrong",
        "hub.challenge" => "abc123"
      }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /chatbot/webhooks/whatsapp" do
    it "acknowledges receipt with 200" do
      post "/chatbot/webhooks/whatsapp", params: { entry: [] }.to_json, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "unknown provider" do
    it "returns 400 for GET" do
      get "/chatbot/webhooks/unknown"
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 for POST" do
      post "/chatbot/webhooks/unknown", params: {}.to_json, headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
