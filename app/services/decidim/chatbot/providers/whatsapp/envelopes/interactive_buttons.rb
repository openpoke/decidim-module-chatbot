# frozen_string_literal: true

module Decidim
  module Chatbot
    module Providers
      module Whatsapp
        module Envelopes
          class InteractiveButtons < Base
            def body
              super.merge(
                type: "interactive",
                interactive: {
                  type: "button",
                  header: {}.tap do |header|
                    if data[:header_text].present?
                      header[:type] = "text"
                      header[:text] = data[:header_text]
                    elsif data[:header_image].present?
                      header[:type] = "image"
                      header[:image] = { link: data[:header_image] }
                    end
                  end,
                  body: {
                    text: data[:body_text]
                  },
                  footer: { text: data[:footer_text] },
                  action: {
                    buttons: data[:buttons].map do |button|
                      { type: "reply", reply: { id: button[:id], title: button[:title] } }
                    end
                  }
                }.tap do |interactive|
                  interactive.delete(:header) if data[:header_text].blank? && data[:header_image].blank?
                  interactive.delete(:footer) if data[:footer_text].blank?
                end
              )
            end
          end
        end
      end
    end
  end
end
