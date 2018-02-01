require_relative 'application_record'

class ChargeShippingLine < ActiveRecord::Base
  include ApplicationRecord
  self.table_name = 'charges_shipping_lines'
  belongs_to :charge
end
