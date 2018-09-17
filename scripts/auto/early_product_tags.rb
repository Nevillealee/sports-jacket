#!/bin/ruby
# products must be manually tagged FIRST
# according to specs in worker/monthly_setup.rb
require_relative '../../config/environment'
@next_mon = Date.today >> 1
month_start = Time.local("#{@next_mon.strftime('%Y')}", "#{@next_mon.strftime('%m')}")
month_end = month_start.end_of_month
base_tag = { active_start: month_start, active_end: month_end }
early_tag = { active_start: nil, active_end: month_end }
# sunset the old tags without an active_end
ProductTag.where(active_end: nil).update_all(active_end: month_start - 1.second)

# main: prepaid products (CURRENTLY TEST VALUES)
prepaid_3 = 614485950496
# prepaid_5 = 614485950496
ProductTag.create_with(early_tag).find_or_create_by(product_id: prepaid_3, tag: 'prepaid').update(early_tag)
# ProductTag.create_with(early_tag).find_or_create_by(product_id: prepaid_5, tag: 'prepaid').update(early_tag)

# main Current month
main_3 = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_main_3%';").first.shopify_id
main_5 = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_main_5%';").first.shopify_id
main_3_autorenew = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_main_AR3%';").first.shopify_id
main_5_autorenew = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_main_AR5%';").first.shopify_id

ProductTag.create_with(early_tag).find_or_create_by(product_id: main_3, tag: 'current').update(early_tag)
ProductTag.create_with(early_tag).find_or_create_by(product_id: main_5, tag: 'current').update(early_tag)
ProductTag.create_with(early_tag).find_or_create_by(product_id: main_3, tag: 'skippable').update(early_tag)
ProductTag.create_with(early_tag).find_or_create_by(product_id: main_5, tag: 'skippable').update(early_tag)
ProductTag.create_with(early_tag).find_or_create_by(product_id: main_3, tag: 'switchable').update(early_tag)
ProductTag.create_with(early_tag).find_or_create_by(product_id: main_5, tag: 'switchable').update(early_tag)
ProductTag.create_with(early_tag).find_or_create_by(product_id: main_3_autorenew, tag: 'current').update(early_tag)
ProductTag.create_with(early_tag).find_or_create_by(product_id: main_5_autorenew, tag: 'current').update(early_tag)
ProductTag.create_with(early_tag).find_or_create_by(product_id: main_3_autorenew, tag: 'skippable')
ProductTag.create_with(early_tag).find_or_create_by(product_id: main_5_autorenew, tag: 'skippable')
ProductTag.create_with(early_tag).find_or_create_by(product_id: main_3_autorenew, tag: 'switchable')
ProductTag.create_with(early_tag).find_or_create_by(product_id: main_5_autorenew, tag: 'switchable')

# alt 1 Current month
alt1_3 = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_alt1_3%';").first.shopify_id
alt1_5 = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_alt1_5%';").first.shopify_id
alt1_3_autorenew = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_alt1_AR3%';").first.shopify_id
alt1_5_autorenew = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_alt1_AR5%';").first.shopify_id
ProductTag.create_with(early_tag).find_or_create_by(product_id: alt1_3, tag: 'current')
ProductTag.create_with(early_tag).find_or_create_by(product_id: alt1_5, tag: 'current')
ProductTag.create_with(early_tag).find_or_create_by(product_id: alt1_3_autorenew, tag: 'current')
ProductTag.create_with(early_tag).find_or_create_by(product_id: alt1_5_autorenew, tag: 'current')

# alt 2 Current month
alt2_3 = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_alt2_3%';").first.shopify_id
alt2_5 = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_alt2_5%';").first.shopify_id
alt_2_3_autorenew = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_alt2_AR3%';").first.shopify_id
alt_2_5_autorenew = Product.find_by_sql("SELECT shopify_id from products where tags LIKE '%#{@next_mon.strftime('%m%y')}_alt2_AR5%';").first.shopify_id
ProductTag.create_with(early_tag).find_or_create_by(product_id: alt2_3, tag: 'current')
ProductTag.create_with(early_tag).find_or_create_by(product_id: alt2_5, tag: 'current')
ProductTag.create_with(early_tag).find_or_create_by(product_id: alt_2_3_autorenew, tag: 'current')
ProductTag.create_with(early_tag).find_or_create_by(product_id: alt_2_5_autorenew, tag: 'current')
