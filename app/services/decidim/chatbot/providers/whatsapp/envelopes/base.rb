# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        module Envelopes
          class Base
            def initialize(to:, data:)
              @to = to
              @data = data
            end

            attr_reader :to, :data

            def body
              {
                messaging_product: "whatsapp",
                recipient_type: "individual",
                to:
              }
            end
          end
        end
      end
    end
  end
end
