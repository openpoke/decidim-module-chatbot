# frozen_string_literal: true

module Decidim
  module Chatbot
    class BaseProcessor
      def initialize(params:)
        @params = params
      end

      attr_reader :params

      def verify
        {
          status: :not_implemented
        }
      end
    end
  end
end
