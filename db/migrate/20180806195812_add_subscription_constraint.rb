class AddSubscriptionConstraint < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL
      alter table subscriptions
        add constraint sub_id unique (subscription_id);
    SQL
  end

  def down
    execute <<-SQL
      alter table subscriptions
        drop constraint if exists sub_id;
    SQL
  end
end
