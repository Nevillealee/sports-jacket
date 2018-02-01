require_relative 'application_record'

class SubLineItem < ActiveRecord::Base
  include ApplicationRecord

  self.primary_key = :subscription_id

  belongs_to :subscription

  SIZE_PROPERTIES = ['leggings', 'tops', 'sports-jacket', 'sports-bra'].freeze
  SIZE_VALUES = %w[XS S M L XL].freeze

  validate do |sub_item|
    if SIZE_PROPERTIES.include?(sub_item.name) && !SIZE_VALUES.include?(sub_item.value)
      sub_items.errors[:value] << 'Invalid size'
    end
  end

  def size_property?
    SIZE_PROPERTIES.include? name
  end
end
