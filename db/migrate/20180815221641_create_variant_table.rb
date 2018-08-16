class CreateVariantTable < ActiveRecord::Migration[5.1]
  def up
    create_table :ellie_variants do |t|
      t.bigint :variant_id
      t.string :title
      t.decimal :price, precision: 10, scale: 2
      t.bigint :sku
      t.integer :position
      t.string :inventory_policy
      t.decimal :compare_at_price, precision: 10, scale: 2
      t.bigint :product_id
      t.string :fulfillment_service
      t.string :inventory_management
      t.string :option1
      t.string :option2
      t.string :option3
      t.datetime :created_at
      t.datetime :updated_at
      t.boolean :taxable
      t.string :barcode
      t.decimal :weight, precision: 10, scale: 2
      t.string :weight_unit
      t.integer :inventory_quantity
      t.bigint :image_id
      t.integer :grams
      t.bigint :inventory_item_id
      t.string :tax_code
      t.integer :old_inventory_quantity
      t.boolean :requires_shipping

    end
  end

  def down
    drop_table :ellie_variants
  end
end
