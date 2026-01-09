class CreateDecidimChatbotMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :decidim_chatbot_messages do |t|
      t.string :provider, null: false, index: true
      t.string :external_id, null: false, index: true
      t.jsonb :content, null: false, default: {}
      t.timestamps
    end
  end
end
