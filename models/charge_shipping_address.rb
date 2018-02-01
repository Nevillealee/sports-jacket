require_relative 'application_record'

class ChargeShippingAddress < ActiveRecord::Base
  include ApplicationRecord
  self.table_name = 'charges_shipping_address'
  belongs_to :charge
end

