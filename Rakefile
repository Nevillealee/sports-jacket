require_relative 'config/environment'
require 'sinatra/activerecord/rake'
require 'resque/tasks'

Dir['worker/**/*.rb'].each do |file|
  require_relative file
end

Resque.logger =
  if ENV['production']
    Logger.new STDOUT, level: Logger::WARNING
  else
    Logger.new STDOUT, level: Logger::INFO
  end

namespace :auto_config do
  desc 'auto configures switchable table'
  task :switchable do
    MonthlySetup.new.switchable_config
  end

  desc 'auto configures alternate table'
  task :alternate do
    MonthlySetup.new.alternate_config
  end

  desc 'auto configures matching table'
  task :matching do
    MonthlySetup.new.matching_config
  end

 # run ellie_pull[products] then  'ruby early_product_tags.rb' (scripts/auto/early_product_tags.rb)
  desc 'runs entire auto config block'
  task :splat => [:alternate, :matching, :switchable]
end

# NEW (Neville 8/15/18)
desc 'arg = products, collects, or custom_collections'
task :ellie_pull, [:args] do |t, args|
  DetermineInfo::InfoGetter.new.handle_ellie(*args)
end

desc 'do full or partial pull of customers and add to DB'
task :customer_pull, [:args] do |t, args|
  DetermineInfo::InfoGetter.new.handle_customers(*args)
end

desc 'do full or partial pull of shopify customers and add to DB'
task :shopify_customer_pull, [:args] do |t, args|
  DetermineInfo::InfoGetter.new.handle_shopify_customers(*args)
end

desc 'do full or partial pull of charge table and associated tables and add to DB'
task :charge_pull, [:args] do |t, args|
  DetermineInfo::InfoGetter.new.handle_charges(*args)
end

desc 'do full or partial pull of order table and associated tables and add to DB'
task :order_pull, [:args] do |t, args|
  DetermineInfo::InfoGetter.new.handle_orders(*args)
end

desc 'do full or partial pull of subscription table and associated tables and add to DB'
task :subscription_pull, [:args] do |t, args|
  DetermineInfo::InfoGetter.new.handle_subscriptions(*args)
end

desc 'run all tests'
task :test do
  require 'rake/testtask'
  Rake::TestTask.new do |t|
    t.pattern = 'test/*_test.rb'
  end
end

desc 'set up subscriptions_updated table, delete old data and reset id sequence'
task :setup_subscriptions_updated do |t|
  DetermineInfo::InfoGetter.new.setup_subscription_update_table

end


desc 'update subscription properties sku, title, product_id, variant_id'
task :update_subscription_product do |t|
  DetermineInfo::InfoGetter.new.update_subscription_product

end


desc 'load current product key-value pairs into current_products table for updating subscriptions'
task :load_current_product do |t|
  DetermineInfo::InfoGetter.new.load_current_products
end


desc 'load update_products table with new data for updating the subscriptions each month'
task :load_update_products do |t|
  DetermineInfo::InfoGetter.new.load_update_products
end

desc 'sync products table'
task :sync_products do |t|
  ShopifyPull.async :all_products
end
#
#load_skippable_products
desc 'load this months skippable products for customers valid skippable products'
task :load_switchable_products do |t|
  DetermineInfo::InfoGetter.new.load_switchable_products
end

#load_matching_products
desc 'load matching products for this month to allow customers to switch to alternate products'
task :load_matching_products do |t|
  DetermineInfo::InfoGetter.new.load_matching_products
end

#load_alternate_products
desc 'load alternate_products table for this month to allow customers to switch to alternate products'
task :load_alternate_products do |t|
  DetermineInfo::InfoGetter.new.load_alternate_products
end
