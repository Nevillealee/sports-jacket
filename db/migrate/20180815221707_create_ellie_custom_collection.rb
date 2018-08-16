class CreateEllieCustomCollection < ActiveRecord::Migration[5.1]
  def up
    create_table :ellie_custom_collections do |t|
      t.bigint :collection_id
      t.string :handle
      t.string :title
      t.datetime :updated_at
      t.text :body_html
      t.datetime :published_at
      t.string :sort_order
      t.string :template_suffix
      t.string :published_scope

    end
  end

  def down
    drop_table :ellie_custom_collections
  end
end
