#!/usr/bin/env ruby

require 'httparty'
require 'nokogiri'
require 'json'
require 'fileutils'

# Configuration
USER_ID = ENV['GOODREADS_USER_ID'] || '146493162'
DATA_DIR = '_data'
DATA_FILE = File.join(DATA_DIR, 'goodreads-reading.json')
PREVIOUS_LIMIT = 3

def clean_title(title)
  # Remove parenthetical phrases at the end of titles
  title.gsub(/\s*\([^)]+\)\s*$/, '').strip
end

def book_identity(book)
  return nil if book.nil?

  bid = book['book_id'].to_s.strip
  return bid unless bid.empty?

  book['title'].to_s.strip
end

def extract_first_book_from_xml(xml)
  doc = Nokogiri::XML(xml) do |config|
    config.nonet.noblanks
  end

  first_item = doc.xpath('//item').first
  return nil unless first_item

  title_node = first_item.xpath('title').first
  raw_title = title_node ? title_node.text.strip : ''
  title = clean_title(raw_title)

  author_node = first_item.xpath('author_name').first
  author = author_node ? author_node.text.strip : ''

  book_id_node = first_item.xpath('book_id').first
  book_id = book_id_node ? book_id_node.text.strip : nil

  book_url = if book_id && !book_id.empty?
    "https://www.goodreads.com/book/show/#{book_id}"
  else
    link_node = first_item.xpath('link').first
    link_node ? link_node.text.strip : ''
  end

  return nil if title.empty?

  {
    'title' => title,
    'author' => author,
    'url' => book_url,
    'book_id' => book_id
  }
end

# Fetch currently reading books
current_book = nil
last_read_book = nil

currently_reading_url = "https://www.goodreads.com/review/list_rss/#{USER_ID}?shelf=currently-reading"
begin
  xml = HTTParty.get(currently_reading_url, timeout: 10).body
  if xml && !xml.strip.empty?
    current_book = extract_first_book_from_xml(xml)
  end
rescue => e
  STDERR.puts "Warning: Failed to fetch currently-reading shelf: #{e.message}"
end

existing_data = {}
if File.exist?(DATA_FILE)
  begin
    existing_data = JSON.parse(File.read(DATA_FILE))
  rescue => e
    STDERR.puts "Warning: Failed to parse existing data file: #{e.message}"
  end
end

previous_titles = existing_data['previous_book_titles'] || []
old_current = existing_data['current_book']
old_last_read = existing_data['last_read_book']

# Derive "last read" from the previously-current book, so editing an old review
# doesn't reorder what we consider "last read".
#
# Heuristic:
# - If the current book changed (including disappearing), treat the previous current
#   as the most recent "last read".
if book_identity(old_current) && book_identity(old_current) != book_identity(current_book)
  last_read_book = old_current
else
  last_read_book = old_last_read
end

if book_identity(old_current) != book_identity(current_book)
  if old_current && !old_current['title'].to_s.strip.empty?
    t = old_current['title'].strip
    previous_titles = ([t] + previous_titles).uniq.take(PREVIOUS_LIMIT)
  end
end

new_data = {
  'current_book' => current_book,
  'last_read_book' => last_read_book,
  'previous_book_titles' => previous_titles,
  'last_updated' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
}

data_changed = (new_data.to_json != existing_data.to_json)

FileUtils.mkdir_p(DATA_DIR)
File.write(DATA_FILE, JSON.pretty_generate(new_data))

puts 'Goodreads reading data updated'
puts "Current book: #{current_book ? current_book['title'] : 'None'}"
puts "Last read book: #{last_read_book ? last_read_book['title'] : 'None'}"
puts "Previous titles: #{previous_titles.inspect}"
puts "Data changed: #{data_changed}"

exit 0
