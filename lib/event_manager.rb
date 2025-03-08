# frozen_string_literal: true

require 'csv'
require 'erb'

require 'google/apis/civicinfo_v2'

def clean_zip_code(zip_code)
  zip_code.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  digits = phone_number.scan(/\d/)

  return '' unless digits.length.between?(10, 11)
  return '' unless digits.length == 10 || digits.first == '1'

  digits.last(10).join
end

def target_time_of_day(data)
  times = data.map do |row|
    Time.strptime(row[:regdate], '%m/%d/%y %k:%M')
  end

  times.each_with_object(Hash.new(0)) do |time, counts|
    counts[time.hour] += 1
  end
end

def target_day_of_week(data)
  times = data.map do |row|
    Time.strptime(row[:regdate], '%m/%d/%y %k:%M')
  end

  times.each_with_object(Hash.new(0)) do |time, counts|
    counts[time.wday] += 1
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue Google::Apis::ClientError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

exit unless File.exist? 'event_attendees.csv'

puts 'Event Manager Initialized!'

data = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.html.erb')
erb_template = ERB.new template_letter

data.each do |row|
  id = row[0]
  name = row[:first_name]
  zip_code = clean_zip_code(row[:zipcode])
  legislators = legislators_by_zipcode(zip_code)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end
