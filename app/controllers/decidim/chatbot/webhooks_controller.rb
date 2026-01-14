# frozen_string_literal: true

module Decidim
  module Chatbot
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token

      before_action do
        render json: { error: "Provider [#{provider}] not supported" }, status: :bad_request unless setting&.adapter_manifest
      end

      # GET /chatbot/webhooks/:provider
      # Used by some providers (e.g., WhatsApp) to verify the endpoint
      def verify
        result = workflow.adapter.verify!

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
        Rails.logger.info("Webhook received from: #{provider}")

        head workflow.start[:status]
      end

      private

      def provider
        params[:provider].to_s
      end

      def setting
        @setting ||= Decidim::Chatbot::Setting.find_by(organization: current_organization, provider:)
      end

      def workflow
        @workflow ||= setting.workflow.new(params.merge(organization: current_organization))
      end
    end
  end
end
