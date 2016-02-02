require_relative '../setup'

GOOGLE_CLIENT = GoogleClient.new
TWILIO_CLIENT = Twilio::REST::Client.new(
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
  "questionnaire: #{ENV['QUESTIONNAIRE_LINK']}"
end

def round_down_to_30_minutes(time)
  round_to_seconds = 30 * 60

  Time.at(time.to_i / round_to_seconds * round_to_seconds).localtime('-05:00')
end

def hour_minute(time_or_string)
  return time_or_string.strftime('%H%M') if time_or_string.is_a?(Time)

  time_or_string.to_s
    .gsub(/\D/, '') # Remove non-digits
    .gsub(/^(\d{1,2})$/, '\100') # 0-pad the minutes if missing
    .gsub(/^(\d{3})$/, '0\1') # 0-pad the hour if necessary
end

def send_email(email, first_name, last_name)
  return unless email && !email.empty?

  message = Mail.new do
    to "#{first_name} #{last_name} <#{email}>".strip
    from "#{ENV['EMAIL_NAME']} <#{ENV['EMAIL_USERNAME']}>"
    subject 'Reminder - Fill out your questionnaire'
    body email_message(first_name)
  end

  GOOGLE_CLIENT.send_message(message)
end

def send_sms(phone, first_name)
  return unless phone && !phone.empty?

  TWILIO_CLIENT.account.messages.create(
    :from => ENV['TWILIO_PHONE_NUMBER'],
    :to => phone,
    :body => sms_message(first_name)
  )
end

response = Faraday.get("https://docs.google.com/spreadsheets/d/#{ENV['GOOGLE_SHEET_ID']}/export?format=csv")
participants = CSV.parse(response.body)[1..-1]

puts "Starting sync #{Time.now} for #{participants.count} participants"

participants.each do |row|
  first_name, last_name, email, phone, notification_time, start_date, end_date = row

  name = "#{first_name} #{last_name}"
  current_time = Time.now.localtime('-05:00')
  current_date = current_time.to_date

  rounded_time = round_down_to_30_minutes(current_time)

  if current_date < Date.parse(start_date)
    puts "Skipping #{name} because it's before their start date."
    next
  end

  if current_date > Date.parse(end_date)
    puts "Skipping #{name} because it's after their end date."
    next
  end

  if hour_minute(notification_time) != hour_minute(rounded_time)
    puts "Skipping #{name} because their notification time is #{notification_time} and it's #{rounded_time}."
    next
  end

  messages_sent = []

  if send_email(email, first_name, last_name)
    messages_sent << "email (#{email})"
  end

  if send_sms(phone, first_name)
    messages_sent << "SMS (#{phone})"
  end

  puts "++ Sent #{messages_sent.empty? ? 'nothing' : messages_sent.join(', ')} to #{name}"
  sleep(1)
end
