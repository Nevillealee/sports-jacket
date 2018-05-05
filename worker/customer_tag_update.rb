#require_relative 'resque_helper'
require_relative '../lib/logging'
require 'shopify_api'
require 'dotenv'
Dotenv.load

class CustomerTagUpdate
  extend ResqueHelper
  @queue = "update_customer_tag"
  def self.perform(params)
    puts "worker running"
    puts params.inspect
    puts params['customer_id']
    Resque.logger = Logger.new("#{Dir.getwd}/logs/terms_conditions.log")

    apikey = ENV['SHOPIFY_API_KEY']
    shopname = ENV['SHOPIFY_SHOP_NAME']
    password = ENV['SHOPIFY_PASSWORD']
    ShopifyAPI::Base.site = "https://#{apikey}:#{password}@#{shopname}.myshopify.com/admin"
    #puts apikey, shopname, password
    
    Resque.logger.info("HEre is apikey, shopname, password: #{apikey}, #{shopname}, #{password}")
    Resque.logger.info(ShopifyAPI::Base.site.inspect)
    Resque.logger.info("after base site inspect")
    

    #{"tags"=>"['terms_and_conditions_agreed', etc..]", "captures"=>[], "customer_id"=>"14512370"}
    cust_id = params['customer_id']
    puts "We are working on customer #{cust_id}"
    Resque.logger.info("We are working on customer #{cust_id}")
    shop = ShopifyAPI::Shop.current
    Resque.logger.info("shop = #{shop.inspect}")
    
    mycustomer = ShopifyAPI::Customer.find(cust_id)
    Resque.logger.info("Here is the shopify customer #{mycustomer.inspect}")
    puts mycustomer.tags
    Resque.logger.info("here is the shopify customer tags #{mycustomer.tags.inspect}")
    mytags = Array.new
    mytags = mycustomer.tags.split(",")
    puts mytags
    if mytags.include? "terms_and_conditions_agreed"
        puts "nothing to do, customer already has tags"
        Resque.logger.info("nothing to do, customer already has tags for terms and conditions")
    else
        puts "Adding terms and conditions tags"
        mytags << "terms_and_conditions_agreed"
        newtags = mytags.join(", ")
        mycustomer.tags = newtags
        mycustomer.save
        puts "Customer tags are now #{mycustomer.tags}"
        Resque.logger.info("Customer tags are now #{mycustomer.tags}")
    end

  end
end