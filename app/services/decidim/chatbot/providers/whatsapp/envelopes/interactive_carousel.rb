# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        module Envelopes
          class InteractiveCarousel < Base
            def body
              super.merge(
                type: "interactive",
                interactive: {
                  type: "carousel",
                  body: {
                    text: data[:body_text]
                  },
                  action: {
                    cards:
                  }
                }
              )
            end

            def cards
              data[:cards].map.with_index do |card, index|
                {
                  type: "cta_url", # This is necessary, even if we're not using the URL feature
                  card_index: index,
                  header: {
                    type: "image",
                    image: {
                      link: card[:image_url]
                    }
                  },
                  body: {
                    text: card[:body_text]
                  },
                  action: {
                    buttons: [
                      {
                        type: "quick_reply",
                        quick_reply: {
                          id: card[:id],
                          title: card[:title]
                        }
                      }
                    ]
                  }
                }
              end
            end
          end
        end
      end
    end
  end
end
