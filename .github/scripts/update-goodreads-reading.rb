#!/usr/bin/env ruby

require 'httparty'
require 'nokogiri'
require 'json'
require 'fileutils'

# Configuration
USER_ID = ENV['GOODREADS_USER_ID'] || '146493162'
DATA_DIR = '_data'
DATA_FILE = File.join(DATA_DIR, 'goodreads-reading.json')

def extract_first_book_from_xml(xml)
  doc = Nokogiri::XML(xml) do |config|
    config.nonet.noblanks
  end
  
  # Get the first item
  first_item = doc.xpath('//item').first
  return nil unless first_item

  # Extract book information (handle CDATA and HTML entities)
  title_node = first_item.xpath('title').first
  title = title_node ? title_node.text.strip : ''
  
  author_node = first_item.xpath('author_name').first
  author = author_node ? author_node.text.strip : ''
  
  book_id_node = first_item.xpath('book_id').first
  book_id = book_id_node ? book_id_node.text.strip : nil
  
  # Construct the book URL
  book_url = if book_id && !book_id.empty?
    "https://www.goodreads.com/book/show/#{book_id}"
  else
    # Fallback: try to extract from link
    link_node = first_item.xpath('link').first
    link = link_node ? link_node.text.strip : ''
    link
  end

  # Return nil if we don't have at least a title
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

# If no current book, fetch the read shelf for last read
if current_book.nil?
  read_url = "https://www.goodreads.com/review/list_rss/#{USER_ID}?shelf=read"
  begin
    xml = HTTParty.get(read_url, timeout: 10).body
    if xml && !xml.strip.empty?
      last_read_book = extract_first_book_from_xml(xml)
    end
  rescue => e
    STDERR.puts "Warning: Failed to fetch read shelf: #{e.message}"
  end
end

# Read existing data if it exists
existing_data = {}
if File.exist?(DATA_FILE)
  begin
    existing_data = JSON.parse(File.read(DATA_FILE))
  rescue => e
    STDERR.puts "Warning: Failed to parse existing data file: #{e.message}"
  end
end

# Prepare new data
new_data = {
  'current_book' => current_book,
  'last_read_book' => last_read_book,
  'last_updated' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
}

# Check if data has changed
data_changed = (new_data.to_json != existing_data.to_json)

# Write the data file
FileUtils.mkdir_p(DATA_DIR)
File.write(DATA_FILE, JSON.pretty_generate(new_data))

puts "Goodreads reading data updated"
puts "Current book: #{current_book ? current_book['title'] : 'None'}"
puts "Last read book: #{last_read_book ? last_read_book['title'] : 'None'}"
puts "Data changed: #{data_changed}"

exit 0

