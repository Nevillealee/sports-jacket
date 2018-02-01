class ModifyAlternateProducts < ActiveRecord::Migration[5.1]
     def up
        add_column :alternate_products, :product_collection, :string
    
     end

    def down
      remove_column :alternate_products, :product_collection, :string
    
    end


end
