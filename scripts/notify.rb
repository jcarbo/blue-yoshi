require_relative '../setup'

response = Faraday.get("https://docs.google.com/spreadsheets/d/#{ENV['GOOGLE_SHEET_ID']}/export?format=csv")
participants = CSV.parse(response.body)[1..-1]

puts "Starting sync #{Time.now} for #{participants.count} participants"

twilio_client = Twilio::REST::Client.new(
  ENV['TWILIO_ACCOUNT_SID'],
  ENV['TWILIO_AUTH_TOKEN']
)

def email_message(first_name)
  "Hey #{first_name},\n\n" \
  "Please take a moment to fill out your questionnaire:\n" \
  "#{ENV['QUESTIONNAIRE_LINK']}"
end

def sms_message(first_name)
  "Hey #{first_name}, please take a moment to fill out your " \
  "questionnaire: ENV['QUESTIONNAIRE_LINK']"
end

participants.each do |row|
  first_name, last_name, email, phone, notification_hour, start_date, end_date = row

  name = "#{first_name} #{last_name}"
  current_time = Time.now.localtime('-05:00') # Get the current time in EST.
  current_date = current_time.to_date

  if current_date < Date.parse(start_date)
    puts "Skipping #{name} because it's before their start date."
    next
  end

  if current_date > Date.parse(end_date)
    puts "Skipping #{name} because it's after their end date."
    next
  end

  if notification_hour.to_i != current_time.hour
    puts "Skipping #{name} because their notification hour is #{notification_hour} and it's #{current_time.hour}."
    next
  end

  twilio_client.account.messages.create(
    :from => ENV['TWILIO_PHONE_NUMBER'],
    :to => phone,
    :body => sms_message(first_name)
  )

  Mail.deliver do
       to email
     from "#{ENV['EMAIL_NAME']} <#{ENV['EMAIL_USERNAME']}>"
  subject 'Reminder - Fill out your questionnaire'
     body email_message(first_name)
  end
end
