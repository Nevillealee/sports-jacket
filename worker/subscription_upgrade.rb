
require_relative 'resque_helper'
class SubscriptionUpgrade
  extend ResqueHelper
  @queue = "upgrade_sub"
  def self.perform(params)
    puts params.inspect
    Resque.logger = Logger.new("#{Dir.getwd}/logs/3to5update.log")
    #{"action"=>"upgrade_subscription", "subscription_id"=>"8672750", "product_id"=>"8204555081"}
    subscription_id = params['subscription_id']
    new_product_id = params['new_product_id']
    puts "new product id recieved #{new_product_id}"
    puts "We are working on subscription #{subscription_id}"

    Resque.logger.info("We are working on subscription #{subscription_id}")
    temp_hash = provide_upgrade_product(new_product_id, subscription_id)
    puts temp_hash

    Resque.logger.info("new product info for subscription #{subscription_id} is #{temp_hash}")
    recharge_change_header = params['recharge_change_header']
    puts recharge_change_header
    body = temp_hash.to_json
    puts body
    #Below for email to customer

    params = {"subscription_id" => subscription_id, "action" => "upgrade_subscription", "details" => temp_hash   }
    my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{subscription_id}", :headers => recharge_change_header, :body => body, :timeout => 80)
    puts my_update_sub.inspect
    Resque.logger.info(my_update_sub.inspect)

    update_success = false
    if my_update_sub.code == 200
      Resque.enqueue(SendEmailToCustomer, params)
      #if 200 == 200
      update_success = true
      puts "****** Hooray We have no errors **********"
      Resque.logger.info("****** Hooray We have no errors **********")
    else
      Resque.enqueue(SendEmailToCS, params)
      puts "We were not able to update the subscription"
      Resque.logger.info("We were not able to update the subscription")
    end
  end

  
end
