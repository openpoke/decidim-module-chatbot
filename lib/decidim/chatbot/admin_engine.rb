# frozen_string_literal: true

module Decidim
  module Chatbot
    # This is the engine that runs on the public interface of `Chatbot`.
    class AdminEngine < ::Rails::Engine
      isolate_namespace Decidim::Chatbot::Admin

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      routes do
        # Add admin engine routes here
        # resources :Chatbot do
        #   collection do
        #     resources :exports, only: [:create]
        #   end
        # end
        # root to: "Chatbot#index"
      end

      def load_seed
        nil
      end
    end
  end
end
