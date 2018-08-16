class CreateCollectTable < ActiveRecord::Migration[5.1]
  def up
    create_table :ellie_collects do |t|
      t.bigint :collect_id
      t.bigint :collection_id
      t.bigint :product_id
      t.boolean :featured, default: false
      t.datetime :created_at
      t.datetime :updated_at
      t.bigint :position
      t.string :sort_value

    end
  end

  def down
    drop_table :ellie_collects
  end
end
