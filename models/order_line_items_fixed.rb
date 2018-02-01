require_relative 'application_record'

class OrderLineItemsFixed < ActiveRecord::Base
  include ApplicationRecord
  self.table_name = 'order_line_items_fixed'
  belongs_to :subscription
  belongs_to :order
end
