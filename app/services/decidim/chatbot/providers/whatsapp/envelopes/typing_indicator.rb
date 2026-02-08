# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        module Envelopes
          class TypingIndicator < Base
            def body
              {
                messaging_product: "whatsapp",
                status: "read",
                message_id: data[:message_id],
                typing_indicator: {
                  type: "text"
                }
              }
            end
          end
        end
      end
    end
  end
end
