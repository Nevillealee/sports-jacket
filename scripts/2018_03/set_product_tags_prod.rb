#!/bin/ruby

require './config/environment'

month_start = Time.local(2018, 3)
month_end = month_start.end_of_month
base_tag = { active_start: month_start, active_end: month_end }

# sunset the old tags without an active_end
ProductTag.where(active_end: nil).update_all(active_end: month_start - 1.second)

# main: La Vie en Rose
main_3 = 175540207634
main_5 = 175535685650
main_3_autorenew = 187757723666
main_5_autorenew = 187802026002


ProductTag.find_or_create_by(base_tag.merge(product_id: main_3, tag: 'current'))
ProductTag.find_or_create_by(base_tag.merge(product_id: main_5, tag: 'current'))
ProductTag.find_or_create_by(base_tag.merge(product_id: main_3, tag: 'skippable'))
ProductTag.find_or_create_by(base_tag.merge(product_id: main_5, tag: 'skippable'))
ProductTag.find_or_create_by(base_tag.merge(product_id: main_3, tag: 'switchable'))
ProductTag.find_or_create_by(base_tag.merge(product_id: main_5, tag: 'switchable'))

ProductTag.find_or_create_by(base_tag.merge(product_id: main_3_autorenew, tag: 'current'))
ProductTag.find_or_create_by(base_tag.merge(product_id: main_5_autorenew, tag: 'current'))
ProductTag.find_or_create_by(base_tag.merge(product_id: main_3_autorenew, tag: 'skippable'))
ProductTag.find_or_create_by(base_tag.merge(product_id: main_5_autorenew, tag: 'skippable'))
ProductTag.find_or_create_by(base_tag.merge(product_id: main_3_autorenew, tag: 'switchable'))
ProductTag.find_or_create_by(base_tag.merge(product_id: main_5_autorenew, tag: 'switchable'))



# alt 1 All Star
alt1_3 = 175542632466
alt1_5 = 175542304786
alt1_3_autorenew = 187810512914
alt1_5_autorenew = 187810971666

ProductTag.find_or_create_by(base_tag.merge(product_id: alt1_3, tag: 'current'))
ProductTag.find_or_create_by(base_tag.merge(product_id: alt1_5, tag: 'current'))
ProductTag.find_or_create_by(base_tag.merge(product_id: alt1_3_autorenew, tag: 'current'))
ProductTag.find_or_create_by(base_tag.merge(product_id: alt1_5_autorenew, tag: 'current'))


# alt 2 Set The Pace
alt2_3 = 175541518354
alt2_5 = 175541026834
alt_2_3_autorenew = 187809366034
alt_2_5_autorenew = 187809988626

ProductTag.find_or_create_by(base_tag.merge(product_id: alt2_3, tag: 'current'))
ProductTag.find_or_create_by(base_tag.merge(product_id: alt2_5, tag: 'current'))
ProductTag.find_or_create_by(base_tag.merge(product_id: alt_2_3_autorenew, tag: 'current'))
ProductTag.find_or_create_by(base_tag.merge(product_id: alt_2_5_autorenew, tag: 'current'))

