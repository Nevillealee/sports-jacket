require_relative 'resque_helper'
require 'sendgrid-ruby'

class SendEmailToCustomer
    extend ResqueHelper
    include Logging
    include SendGrid

    @queue = 'send_customer_confirmation'

    def self.perform(params)
        Resque.logger = Logger.new("#{Dir.getwd}/logs/send_emails_resque.log")
        puts params.inspect
        Resque.logger.info params.inspect

        subscription_id = params['subscription_id']
        myaction = params['action']
        details = params['details']

        puts "subscription_id = #{subscription_id}"
        Resque.logger.info "subscription_id = #{subscription_id}"
        subscription = Subscription.find(subscription_id)
        Resque.logger.info "Subscription is #{subscription.inspect}"
        puts "Subscription is #{subscription.inspect}"
        customer_id = subscription.customer_id
        puts "Customer_id = #{customer_id}"
        mycustomer = Customer.find(customer_id)
        puts mycustomer.inspect

        first_name = mycustomer.first_name
        last_name = mycustomer.last_name
        email = mycustomer.email

        from = Email.new(email: 'no-reply@ellie.com', name: 'Ellie')
        to = Email.new(email: email)

        case myaction
            when 'change_sizes'
                puts "changing sizes"
                leggings_size = details['leggings']
                bra_size = details['sports-bra']
                tops = details['tops']
                my_details = "Leggings: #{leggings_size}\n\n Sports Bra Size: #{bra_size}\n\n Top Size: #{tops}"
                mybody = "Dear #{first_name} #{last_name}:\n\n Here is your confirmation of the size changes for your subscription:\n\n #{my_details} \n\n Your friends at Ellie."
                subject = "Confirmation of Size Change for Your Subscription"
                content = Content.new(type: 'text/plain', value: mybody)
            when 'switching_product'
                puts "switching product"

                my_details = "Your new subscription is for: #{details['product_title']}"
                puts "my_details for content = #{my_details}"
                mybody = "Dear #{first_name} #{last_name}:\n\n Here is your confirmation of the change to your subscription:\n\n #{my_details} \n\n Your friends at Ellie."
                subject = "Confirmation of Switching Your Subscription"
                content = Content.new(type: 'text/plain', value: mybody)


            when 'skipping'
                puts "skipping this month"
                #Skip Month code here
                puts "details = #{details.inspect}"
                new_charge_date = details['date']
                puts "new_charge_date = #{new_charge_date}"

                my_details = "Your new charge date is: #{new_charge_date}"
                mybody = "Dear #{first_name} #{last_name}:\n\n Here is your confirmation of the new charge date for your subscription:\n\n #{my_details} \n\n Your friends at Ellie."
                subject = "Confirmation of Skip for Your Subscription"
                content = Content.new(type: 'text/plain', value: mybody)
                puts "All done sending email"
                Resque.logger.info "all done sending email"

            else
                puts "Doing nothing"

        end

        begin
            mail = Mail.new(from, subject, to, content)
            sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'], host: 'https://api.sendgrid.com')
            response = sg.client.mail._('send').post(request_body: mail.to_json)
            puts response.headers
        rescue Exception => e
            Resque.logger.error(e.inspect)
        else
            puts "Email sent to customer!"
        end

    end
end

class SendEmailToCS
    extend ResqueHelper
    include Logging
    include SendGrid

    @queue = 'send_cs_error_email'
    def self.perform(params)
        puts "Sending to Customer Service"
        puts params.inspect
        subscription_id = params['subscription_id']
        myaction = params['action']
        details = params['details'].to_json
        subscription = Subscription.find(subscription_id)
        subscription_product_title = subscription.product_title
        customer_id = subscription.customer_id
        mycustomer = Customer.find(customer_id)
        puts mycustomer.inspect
        customer_name = "#{mycustomer.first_name} #{mycustomer.last_name}"
        puts customer_name.inspect

        mybody = "Dear Customer Service: \n\n The subscription: \n\n #{subscription_product_title}\n\n for customer:\n\n #{customer_name}\n\n was trying to do: #{myaction}\n\n with details: #{details}\n\n BUT SOMETHING WENT WRONG."

        from = Email.new(email: 'no-reply@ellie.com', name: 'Ellie')
        subject = "Subscription update error"
        to = Email.new(email: 'help@ellie.com')
        content = Content.new(type: 'text/plain', value: mybody)

        begin
            mail = Mail.new(from, subject, to, content)
            sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'], host: 'https://api.sendgrid.com')
            response = sg.client.mail._('send').post(request_body: mail.to_json)
            puts response.headers
        rescue Exception => e
            Resque.logger.error(e.inspect)
        else
            puts "Email sent to customer service."
        end





    end
end
