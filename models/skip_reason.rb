require_relative 'application_record'

class SkipReason < ActiveRecord::Base
  belongs_to :charge
  belongs_to :subscription
  belongs_to :customer, primary_key: :shopify_customer_id, foreign_key: :shopify_customer_id
end
