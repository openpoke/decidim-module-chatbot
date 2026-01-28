# frozen_string_literal: true

module Decidim
  module Chatbot
    module Admin
      class ApplicationController < Decidim::Admin::ApplicationController
        helper Decidim::Chatbot::ApplicationHelper

        def permission_class_chain
          [Decidim::Admin::Permissions]
        end
      end
    end
  end
end
