require 'nokogiri'
require 'httparty'
require 'pp'

class HtmlParserIncluded < HTTParty::Parser
  def html
    Nokogiri::HTML(body)
  end
end

class Page
  include HTTParty
  parser HtmlParserIncluded
end

html_doc = Page.get('http://railsconf.com/program')
activity_names = html_doc.css("h2.session-talk-title a")

pp activity_names.map { |name| name.text.strip }
