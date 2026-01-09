# frozen_string_literal: true

module Decidim
  module Chatbot
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token

      before_action do
        render json: { error: "Provider [#{provider}] not supported" }, status: :bad_request unless processor
      end

      # GET /chatbot/webhooks/:provider
      # Used by some providers (e.g., WhatsApp) to verify the endpoint
      def verify
        result = processor.verify

        if result[:status] == :ok
          render plain: result[:response], status: :ok
        elsif result[:status] == :forbidden
          head :forbidden
        else
          head :not_implemented
        end
      end

      # POST /chatbot/webhooks/:provider
      def receive
        result = processor.receive(request.raw_post)
        # NOTE: Add signature verification per provider in the future.
        # For now, accept payload and respond 200 to acknowledge receipt.

        Rails.logger.info("Webhook received from #{provider}: #{processor.json.inspect}")

        head result[:status]
      end

      private

      def provider
        params[:provider].to_s
      end

      def processor
        manifest = Decidim::Chatbot.providers_registry.find(provider.to_sym)
        return nil unless manifest

        manifest.processor.new(params:)
      end
    end
  end
end
