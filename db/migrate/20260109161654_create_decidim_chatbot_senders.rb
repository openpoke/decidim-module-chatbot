# frozen_string_literal: true

class CreateDecidimChatbotSenders < ActiveRecord::Migration[7.2]
  def change
    create_table :decidim_chatbot_senders do |t|
      t.references :setting, null: false, foreign_key: { to_table: :decidim_chatbot_settings }, index: true
      t.references :decidim_user, null: true, foreign_key: { to_table: :decidim_users }, index: true
      t.string :from, null: false
      t.string :name, null: true
      t.jsonb :metadata, null: true
      t.string :current_workflow_class, null: true
      t.string :parent_workflow_class, null: true
      t.timestamps

      t.index [:setting_id, :from], unique: true, name: "index_decidim_chatbot_senders_on_setting_and_from"
    end
  end
end
