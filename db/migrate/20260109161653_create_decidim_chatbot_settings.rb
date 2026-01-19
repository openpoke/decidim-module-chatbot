# frozen_string_literal: true

class CreateDecidimChatbotSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :decidim_chatbot_settings do |t|
      t.references :decidim_organization, null: false, foreign_key: { to_table: :decidim_organizations }, index: true
      t.string :provider, null: false
      t.string :start_workflow, null: false
      t.jsonb :config, null: false, default: {}
      t.timestamps

      t.index [:decidim_organization_id, :provider, :start_workflow], unique: true, name: "index_decidim_chatbot_settings_on_org_and_provider"
    end
  end
end
