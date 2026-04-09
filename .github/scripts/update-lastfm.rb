#!/usr/bin/env ruby

require 'httparty'
require 'json'
require 'yaml'
require 'fileutils'

USER = ENV['LASTFM_USER'] || 'uilydna'
API_KEY = ENV['LASTFM_API_KEY']
DATA_DIR = '_data'
DATA_FILE = File.join(DATA_DIR, 'lastfm.yml')
PREVIOUS_LIMIT = 3
PROFILE_URL = "https://www.last.fm/user/#{USER}"

unless API_KEY && !API_KEY.strip.empty?
  STDERR.puts 'LASTFM_API_KEY is not set. Exiting.'
  exit 0
end

url = "http://ws.audioscrobbler.com/2.0/?method=user.gettopartists&user=#{USER}&period=7day&limit=1&api_key=#{API_KEY}&format=json"

begin
  response = HTTParty.get(url, timeout: 15)
  body = response.parsed_response
rescue => e
  STDERR.puts "Warning: Last.fm request failed: #{e.message}"
  exit 0
end

raw = body.dig('topartists', 'artist')
first = case raw
        when Array then raw[0]
        when Hash then raw
        else nil
        end
artist_name = first&.fetch('name', nil)
artist_url = first&.fetch('url', nil)

if artist_name.nil? || artist_name.to_s.strip.empty?
  puts 'No artist data returned or API error. Exiting without changes.'
  exit 0
end

existing = {}
if File.exist?(DATA_FILE)
  begin
    existing = YAML.load_file(DATA_FILE) || {}
  rescue => e
    STDERR.puts "Warning: Failed to parse #{DATA_FILE}: #{e.message}"
  end
end

previous = existing['previous_artists'] || []
old_artist = existing['artist']

if old_artist && old_artist != artist_name
  previous = ([old_artist] + previous).uniq.take(PREVIOUS_LIMIT)
end

today = Time.now.utc.strftime('%Y-%m-%d')

out = {
  'artist' => artist_name,
  'url' => artist_url,
  'profile' => PROFILE_URL,
  'updated' => today,
  'previous_artists' => previous
}

FileUtils.mkdir_p(DATA_DIR)
File.write(DATA_FILE, out.to_yaml)

puts "Updated with artist: #{artist_name}"
puts "Previous artists: #{previous.inspect}"

exit 0
