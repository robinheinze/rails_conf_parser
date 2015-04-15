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


class Schedule
  attr_accessor :session_html, :schedule_html, :parsed_sessions, :days

  def initialize(args = {})
    @session_html = args[:session_html]
    @schedule_html = args[:schedule_html]
    @days = ["2015-04-21", "2015-04-22", "2015-04-23"]
  end

  def parse
    raw_sessions = session_html.css('div.session')
    self.parsed_sessions = raw_sessions.map do |session|
      speaker_bio_pgraphs = session.css('section.bio p')
      description_pgraphs = session.css('p') - speaker_bio_pgraphs

      speaker = Speaker.new(
        display_name: session.css('h3.session-presenter').text.gsub('presented by: ', ''),
        bio: speaker_bio_pgraphs.map(&:to_s).join(' ')
      )

      Session.new(
        unique_id: session.css('a').first['name'],
        name: session.css('h2.session-talk-title a').text.strip,
        description: description_pgraphs.map(&:to_s).join(' '),
        speaker: speaker
      )
    end
    
    day_one_timeslots = schedule_html.css('div#day-1 td.schedule-time-slot') 
    day_two_timeslots = schedule_html.css('div#day-2 td.schedule-time-slot')
    day_three_timeslots = schedule_html.css('div#day-3 td.schedule-time-slot')
    
    parse_timeslots(0, day_one_timeslots)
    parse_timeslots(1, day_two_timeslots)
    parse_timeslots(2, day_three_timeslots)
        
  end
  
  def parse_timeslots(day, timeslots)
    timeslots.each do |timeslot|
      times = timeslot.text.strip.split(' - ')
      start_time = times.first
      end_time = times.last

      activities = timeslot.css('~ td p').map { |a| a.text.strip }

      activities.each do |activity|
        session = parsed_sessions.detect { |session| session.name == activity }
        session.start_datetime = days[day] + " " + start_time if session
        session.end_datetime = days[day] + " " + end_time if session
      end
    end
  end

end

class Session
  attr_accessor :unique_id, :name, :description, :speaker, :start_datetime, :end_datetime

  def initialize(args = {})
    @unique_id = args[:unique_id]
    @name = args[:name]
    @description = args[:description]
    @start_datetime = args[:start_datetime]
    @end_datetime = args[:end_datetime]
    @speaker = args[:speaker]
  end
  
end

class Speaker
  attr_accessor :display_name, :bio

  def initialize(args = {})
    @display_name = args[:display_name]
    @bio = args[:bio]
  end

end

sched = Schedule.new(
  :session_html => Page.get('http://railsconf.com/program'), 
  :schedule_html => Page.get('http://railsconf.com/schedule')
)
sched.parse

CSV.open('rails_conf_sessions.csv', 'wb') do |csv|
  sched.parsed_sessions.each do |session|
    csv << [
      session.unique_id, 
      session.name, 
      session.description.gsub("\n", " "), 
      session.start_datetime, 
      session.end_datetime, 
      session.speaker.display_name,
      session.speaker.bio.gsub("\n", " ") 
    ]
  end
end
