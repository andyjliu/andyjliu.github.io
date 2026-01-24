#!/usr/bin/env ruby

require 'httparty'
require 'json'
require 'time'

# Configuration
REPO_OWNER = ENV['GITHUB_REPOSITORY']&.split('/')&.first || 'andyjliu'
REPO_NAME = ENV['GITHUB_REPOSITORY']&.split('/')&.last || 'andyjliu.github.io'
GITHUB_TOKEN = ENV['GITHUB_TOKEN']

def github_api_request(endpoint)
  headers = {
    'Accept' => 'application/vnd.github.v3+json',
    'User-Agent' => 'Deployment-Status-Checker'
  }
  headers['Authorization'] = "token #{GITHUB_TOKEN}" if GITHUB_TOKEN
  
  response = HTTParty.get("https://api.github.com/repos/#{REPO_OWNER}/#{REPO_NAME}#{endpoint}", 
                         headers: headers, timeout: 10)
  
  if response.success?
    JSON.parse(response.body)
  else
    puts "❌ API request failed: #{response.code} - #{response.message}"
    nil
  end
end

def check_recent_commits
  puts "🔍 Checking recent commits..."
  commits = github_api_request('/commits?per_page=10')
  return unless commits
  
  goodreads_commits = commits.select do |commit|
    commit['commit']['message'].include?('Update Goodreads reading data') &&
    commit['commit']['author']['name'] == 'GitHub Action'
  end
  
  if goodreads_commits.empty?
    puts "ℹ️ No recent Goodreads commits found"
    return
  end
  
  puts "📝 Recent Goodreads commits:"
  goodreads_commits.each do |commit|
    commit_time = Time.parse(commit['commit']['author']['date'])
    puts "  - #{commit['sha'][0..7]} at #{commit_time.strftime('%Y-%m-%d %H:%M UTC')}"
  end
  
  goodreads_commits.first
end

def check_workflow_runs(workflow_name, since_time = nil)
  puts "\n🔄 Checking #{workflow_name} workflow runs..."
  
  # Get workflow ID
  workflows = github_api_request('/actions/workflows')
  return unless workflows
  
  workflow = workflows['workflows'].find { |w| w['name'] == workflow_name }
  unless workflow
    puts "❌ Workflow '#{workflow_name}' not found"
    return
  end
  
  # Get recent runs
  endpoint = "/actions/workflows/#{workflow['id']}/runs?per_page=5"
  endpoint += "&created=>=#{since_time.iso8601}" if since_time
  
  runs = github_api_request(endpoint)
  return unless runs
  
  if runs['workflow_runs'].empty?
    puts "ℹ️ No recent runs found for #{workflow_name}"
    return
  end
  
  puts "📊 Recent #{workflow_name} runs:"
  runs['workflow_runs'].each do |run|
    run_time = Time.parse(run['created_at'])
    status_emoji = case run['status']
                   when 'completed'
                     run['conclusion'] == 'success' ? '✅' : '❌'
                   when 'in_progress'
                     '🔄'
                   else
                     '⏸️'
                   end
    
    puts "  #{status_emoji} #{run['display_title']} - #{run['status']} (#{run['conclusion']}) at #{run_time.strftime('%Y-%m-%d %H:%M UTC')}"
  end
  
  runs['workflow_runs']
end

def analyze_deployment_gap
  puts "\n🔍 Analyzing deployment gaps..."
  
  # Get the most recent Goodreads commit
  recent_goodreads = check_recent_commits
  return unless recent_goodreads
  
  goodreads_time = Time.parse(recent_goodreads['commit']['author']['date'])
  puts "\n📅 Most recent Goodreads update: #{goodreads_time.strftime('%Y-%m-%d %H:%M UTC')}"
  
  # Check for deployments after the Goodreads update
  deploy_runs = check_workflow_runs('Deploy site', goodreads_time)
  
  if deploy_runs && !deploy_runs.empty?
    successful_deploys = deploy_runs.select { |run| run['conclusion'] == 'success' }
    if successful_deploys.any?
      latest_deploy = Time.parse(successful_deploys.first['created_at'])
      puts "\n✅ Latest successful deployment: #{latest_deploy.strftime('%Y-%m-%d %H:%M UTC')}"
      
      if latest_deploy > goodreads_time
        puts "✅ Website should be up to date!"
      else
        puts "⚠️ Website may be outdated - no deployment after latest Goodreads update"
      end
    else
      puts "\n⚠️ No successful deployments found after Goodreads update"
    end
  else
    puts "\n⚠️ No deployments found after Goodreads update"
  end
end

def main
  puts "🚀 GitHub Actions Deployment Status Checker"
  puts "=" * 50
  
  unless GITHUB_TOKEN
    puts "⚠️ No GITHUB_TOKEN provided - API rate limits may apply"
  end
  
  analyze_deployment_gap
  
  puts "\n💡 Recommendations:"
  puts "  - If website is outdated, manually trigger 'Deploy site' workflow"
  puts "  - Check GitHub Actions tab for failed workflow runs"
  puts "  - Ensure GitHub Pages is configured correctly in repository settings"
  
  puts "\n🔗 Useful links:"
  puts "  - Actions: https://github.com/#{REPO_OWNER}/#{REPO_NAME}/actions"
  puts "  - Pages settings: https://github.com/#{REPO_OWNER}/#{REPO_NAME}/settings/pages"
end

main if __FILE__ == $0
