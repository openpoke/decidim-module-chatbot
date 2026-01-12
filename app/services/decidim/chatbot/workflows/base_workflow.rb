# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class BaseWorkflow
        def initialize(params)
          @provider = params[:provider]
          @adapter_manifest = Decidim::Chatbot.providers_registry.find(provider.to_sym)
          @adapter = adapter_manifest.adapter.new(params:)
          @params = params
        end

        attr_reader :params, :adapter, :provider, :adapter_manifest

        delegate :build_message, :received_message, to: :adapter

        def process!
          raise NotImplementedError
        end
      end
    end
  end
end
