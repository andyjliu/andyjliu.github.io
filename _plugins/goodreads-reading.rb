require 'feedjira'
require 'httparty'
require 'jekyll'
require 'nokogiri'
require 'json'

module GoodreadsReading
  class GoodreadsReadingGenerator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      # Check if goodreads_reading is enabled
      return unless site.config['goodreads_reading'] && site.config['goodreads_reading']['enabled']

      user_id = site.config['goodreads_reading']['user_id']
      return unless user_id

      current_book = nil
      last_read_book = nil

      # Try to read from cached JSON file first
      data_file = File.join(site.source, '_data', 'goodreads-reading.json')
      if File.exist?(data_file)
        begin
          data = JSON.parse(File.read(data_file))
          current_book = data['current_book']
          last_read_book = data['last_read_book']
          Jekyll.logger.info "Goodreads Reading:", "Loaded from cache file"
        rescue => e
          Jekyll.logger.warn "Goodreads Reading:", "Failed to read cache file: #{e.message}. Fetching live..."
          # Continue to fetch live as fallback
        end
      end

      # If cache file doesn't exist or parsing failed, fetch live
      if current_book.nil? && last_read_book.nil?
        # Fetch currently reading books
        currently_reading_url = "https://www.goodreads.com/review/list_rss/#{user_id}?shelf=currently-reading"
        begin
          xml = HTTParty.get(currently_reading_url, timeout: 10).body
          if xml && !xml.strip.empty?
            current_book = extract_first_book_from_xml(xml)
          end
        rescue => e
          Jekyll.logger.warn "Goodreads Reading:", "Failed to fetch currently-reading shelf: #{e.message}"
        end

        # If no current book, fetch the read shelf for last read
        if current_book.nil?
          read_url = "https://www.goodreads.com/review/list_rss/#{user_id}?shelf=read"
          begin
            xml = HTTParty.get(read_url, timeout: 10).body
            if xml && !xml.strip.empty?
              last_read_book = extract_first_book_from_xml(xml)
            end
          rescue => e
            Jekyll.logger.warn "Goodreads Reading:", "Failed to fetch read shelf: #{e.message}"
          end
        end
      end

      # Store the data in site.data
      site.data['goodreads_reading'] = {
        'current_book' => current_book,
        'last_read_book' => last_read_book
      }
    end

    private

    def clean_title(title)
      # Remove parenthetical phrases at the end of titles
      # Examples: "(Firefall, #1)" or "(Princeton Studies in International History and Politics)"
      # This removes trailing parentheticals that Goodreads adds for series info, publication series, etc.
      title.gsub(/\s*\([^)]+\)\s*$/, '').strip
    end

    def extract_first_book_from_xml(xml)
      doc = Nokogiri::XML(xml) do |config|
        config.nonet.noblanks
      end
      
      # Get the first item
      first_item = doc.xpath('//item').first
      return nil unless first_item

      # Extract book information (handle CDATA and HTML entities)
      title_node = first_item.xpath('title').first
      raw_title = title_node ? title_node.text.strip : ''
      title = clean_title(raw_title)
      
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
  end
end

