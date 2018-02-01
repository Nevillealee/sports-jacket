ActiveRecord::Base.establish_connection(
    :adapter  => "postgresql",
    :host     => "ellie-production-v2.cabmxdxjziky.us-east-1.rds.amazonaws.com",
    :port     => "5432",
    :username => "ellie_dev_team",
    :password => "H4rdC4s3!99",
    :database => "ellie_production"
  ) 