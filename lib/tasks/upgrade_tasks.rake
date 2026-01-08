# frozen_string_literal: true

Rake::Task["decidim:choose_target_plugins"].enhance do
  ENV["FROM"] = [ENV["FROM"], "decidim_chatbot"].compact.join(",")
end
