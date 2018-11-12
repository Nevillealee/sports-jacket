require 'sinatra'
require 'rspec'
require 'rack/test'
require_relative 'spec_helper.rb'
require '../api/ellie_listener.rb'

RSpec.describe EllieListener do
  include Rack::Test::Methods
  @subscription_id = 634474627164
  def app
    EllieListener
  end

  describe "#subscriptions_properties" do
    context "no sub_id param?" do
      it "returns 400 status code" do
        get "/subscriptions_properties"
        expect(last_response.status).to eq 400
        # expect(last_response.body).to eq("Hello, success, thanks for installing me!")
        # expect(last_response.status).to eq 200
      end
    end

    context "valid prepaid sub_id" do
      # let(:last_response) { get "/subscriptions_properties", :subscription_id => "25480977"}
      it "returns properties of next queued order" do
        get "/subscriptions_properties", :shopify_id => @subscription_id
        expect(last_response.body).to eq(last_response.body)
      end

      it "has non-null values for each hash key" do
        get "/subscriptions_properties", :shopify_id => @subscription_id

      end
    end
  end


end
