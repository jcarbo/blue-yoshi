require 'mail'

options = {
  :address => "smtp.gmail.com",
  :port => 587,
  :domain => 'gmail.com',
  :user_name => ENV['EMAIL_USERNAME'],
  :password => ENV['EMAIL_PASSWORD'],
  :authentication => 'plain',
  :enable_starttls_auto => true
}

Mail.defaults do
  delivery_method :smtp, options
end
