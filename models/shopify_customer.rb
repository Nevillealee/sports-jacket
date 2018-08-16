require_relative '../lib/async'
require_relative 'application_record'

class ShopifyCustomer < ActiveRecord::Base
  include ApplicationRecord
  include Async
  self.primary_key = :customer_id
end
