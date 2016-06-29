require_relative '../setup'

Time.zone = 'Eastern Time (US & Canada)'

GOOGLE_CLIENT = GoogleClient.new
TWILIO_CLIENT = Twilio::REST::Client.new(
  ENV['TWILIO_ACCOUNT_SID'],
  ENV['TWILIO_AUTH_TOKEN']
)

def email_message(data)
  formatted_date = Date.parse(data[:end_date]).strftime('%A, %B %-d')
  personalized_link = "#{data[:link]}&CID=#{data[:cid]}"

  lines = [
    "Hi #{data[:first_name]}!",
    '',
    "Please take a moment to fill out your daily sleep survey: #{personalized_link}",
    '',
    "We'll see you soon for your second lab visit on #{formatted_date}.",
    '',
    'Thanks,',
    'PASO Lab'
  ]

  lines.join("\n")
end

def sms_message(data)
  formatted_date = Date.parse(data[:end_date]).strftime('%A, %B %-d')
  personalized_link = "#{data[:link]}&CID=#{data[:cid]}"

  lines = [
    "Hi #{data[:first_name]}! Please take a moment to fill out your daily sleep survey: #{personalized_link}",
    "We'll see you soon for your second lab visit on #{formatted_date}.",
    'Thanks, PASO Lab'
  ]

  lines.join("\n")
end

def round_down_to_30_minutes(time)
  round_to_seconds = 30 * 60

  Time.at(time.to_i / round_to_seconds * round_to_seconds)
end

def hour_minute(time_or_string)
  return time_or_string.strftime('%H%M') if time_or_string.is_a?(Time)

  time_or_string.to_s
    .gsub(/\D/, '') # Remove non-digits
    .gsub(/^(\d{1,2})$/, '\100') # 0-pad the minutes if missing
    .gsub(/^(\d{3})$/, '0\1') # 0-pad the hour if necessary
end

def send_email(email, attributes)
  return unless email && !email.empty?

  message = Mail.new do
    to "#{attributes[:first_name]} #{attributes[:last_name]} <#{email}>".strip
    from "#{ENV['EMAIL_NAME']} <#{ENV['EMAIL_USERNAME']}>"
    subject 'Reminder - Complete your daily sleep survey'
    body email_message(attributes)
  end

  GOOGLE_CLIENT.send_message(message)
end

def send_sms(phone, attributes)
  return unless phone && !phone.empty?

  TWILIO_CLIENT.account.messages.create(
    :from => ENV['TWILIO_PHONE_NUMBER'],
    :to => phone,
    :body => sms_message(attributes)
  )
end

def send_notification(type, attributes)
  rounded_time = round_down_to_30_minutes(Time.now)

  name = "#{attributes[:first_name]} #{attributes[:last_name]}"

  if type == :morning && hour_minute(attributes[:morning_time]) != hour_minute(rounded_time)
    puts "Skipping #{name} because their morning notification time is #{attributes[:morning_time]} and it's #{rounded_time}."
    return
  end

  if type == :evening && hour_minute(attributes[:evening_time]) != hour_minute(rounded_time)
    puts "Skipping #{name} because their evening notification time is #{attributes[:evening_time]} and it's #{rounded_time}."
    return
  end

  link =
    case type
    when :morning then ENV['MORNING_QUESTIONNAIRE_LINK']
    when :evening then ENV['EVENING_QUESTIONNAIRE_LINK']
    else
      return
    end

  messages_sent = []

  if send_email(attributes[:email], attributes.merge(:link => link))
    messages_sent << "email (#{attributes[:email]})"
  end

  if send_sms(attributes[:phone], attributes.merge(:link => link))
    messages_sent << "SMS (#{attributes[:phone]})"
  end

  puts "++ Sent #{messages_sent.empty? ? 'nothing' : messages_sent.join(', ')} to #{name}"
  sleep(1)
end

response = Faraday.get("https://docs.google.com/spreadsheets/d/#{ENV['GOOGLE_SHEET_ID']}/export?format=csv")
participants = CSV.parse(response.body)[1..-1]

puts "Starting sync #{Time.now} for #{participants.count} participants"

participants.each do |row|
  first_name, last_name, email, phone, cid, morning_time, evening_time, start_date, end_date = row

  attributes = {
    :first_name => first_name,
    :last_name => last_name,
    :email => email,
    :phone => phone,
    :cid => cid,
    :morning_time => morning_time,
    :evening_time => evening_time,
    :start_date => start_date,
    :end_date => end_date
  }

  name = "#{first_name} #{last_name}"
  current_date = Time.now.to_date

  if current_date < Date.parse(start_date)
    puts "Skipping #{name} because it's before their start date."
    next
  end

  if current_date > Date.parse(end_date)
    puts "Skipping #{name} because it's after their end date."
    next
  end

  send_notification(:morning, attributes)
  send_notification(:evening, attributes)
end
