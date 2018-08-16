class SwitchableProducts < ActiveRecord::Migration[5.1]
  def up
    create_table :switchable_products do |t|
      t.string :product_title
      t.string :product_id
      t.boolean :threepk, default: false
    end
    add_index :switchable_products, :product_id
  end
  def down
    remove_index :switchable_products, :product_id
    drop_table :switchable_products
  end
end
