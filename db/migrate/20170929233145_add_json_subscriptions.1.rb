class AddJsonSubscriptions < ActiveRecord::Migration[5.1]
  def up 
    add_column :charges, :discount_codes, :jsonb
    
  end

  def down
    remove_column :charges, :discount_codes, :jsonb
  end
end
