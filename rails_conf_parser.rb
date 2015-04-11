require 'nokogiri'
require 'httparty'
require 'pp'
require 'csv'

class HtmlParserIncluded < HTTParty::Parser
  def html
    Nokogiri::HTML(body)
  end
end

class Page
  include HTTParty
  parser HtmlParserIncluded
end

session_html = Page.get('http://railsconf.com/program')

raw_sessions = session_html.css('div.session')
parsed_sessions = raw_sessions.map do |session|
  {}.tap do |hash|
    hash[:unique_id] = session.css('a').first['name']
    hash[:name] = session.css('h2.session-talk-title a').text.strip

    speaker_bio_pgraphs = session.css('section.bio p')
    description_pgraphs = session.css('p') - speaker_bio_pgraphs

    hash[:description] = description_pgraphs.map(&:to_s).join(' ')
    hash[:speaker] = {}.tap do |s| 
      s[:display_name] = session.css('h3.session-presenter').text.gsub('presented by: ', '')
      s[:bio] = speaker_bio_pgraphs.map(&:to_s).join(' ')
    end
  end
end

schedule_html = Page.get('http://railsconf.com/schedule')

days = ['2015-04-21', '2015-04-22', '2015-04-23']
day_one_timeslots = schedule_html.css('div#day-1 td.schedule-time-slot')
day_two_timeslots = schedule_html.css('div#day-2 td.schedule-time-slot')
day_three_timeslots = schedule_html.css('div#day-3 td.schedule-time-slot')

day_one_timeslots.each do |t|
  activities = t.css('~ td p').map { |a| a.text.strip }
  pp activities
end

##CSV.open('rails_conf_sessions.csv', 'wb', encoding: 'utf-8') do |csv|
##  parsed_sessions.each do |session|
##    csv << [session[:unique_id], session[:name], session[:description]]
##  end
##end
