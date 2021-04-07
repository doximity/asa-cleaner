# frozen_string_literal: true

require "aws-sdk-ssm"
require "json"
require "link-header-parser"
require "logger"
require "log_formatter"
require "log_formatter/ruby_json_formatter"
require "net/https"
require "uri"

require_relative "ssm_client"

class Cleaner
  attr_reader :asa_token, :log, :instance_id

  def initialize(instance_id)
    @instance_id = instance_id
    @asa_token = get_asa_api_token
    @last_response = ""

    @log = Logger.new($stdout)
    @log.formatter = Ruby::JSONFormatter::Base.new do |config|
      config[:type] = false
      config[:app] = false
    end
  end

  def run
    log.info({ message: "ASA Cleaner lambda triggered for instance #{@instance_id}", instance_id: @instance_id,
               event_type: "lambda_start", method: "run", env: ENV["ENVIRONMENT"] })

    clean_asa

    log.info({ message: "API requests left: #{@last_response.to_h["x-ratelimit-remaining"]}",
               ratelimit_remaining: @last_response.to_h["x-ratelimit-remaining"],
               event_type: "api_ratelimit_renamining", method: "run", env: ENV["ENVIRONMENT"] })
  end

  def clean_asa
    asa_api_query("projects").each do |project|
      asa_api_query("projects/#{project["name"]}/servers?count=1000").each do |server|
        next if server["instance_details"].nil?

        next unless server["instance_details"]["instance_id"] == @instance_id

        asa_api_delete("projects/#{project["name"]}/servers/#{server["id"]}")
        log.info({ message: "Removed #{server["hostname"]} from #{project["name"]}",
                   instance_id: @instance_id, asa_project: project["name"],
                   asa_hostname: server["hostname"], event_type: "instance_removed",
                   method: "clean_asa", env: ENV["ENVIRONMENT"] })
        return true
      end
    end

    log.info({ message: "Instance #{@instance_id} does not exist in ASA",
               instance_id: @instance_id, event_type: "asa_node_not_found",
               method: "clean_asa", env: ENV["ENVIRONMENT"] })
    false
  end

  def get_asa_api_token(ssm_path)
    asa_api_key = SSMClient.new.get_parameter(ENV["ASA_API_KEY_PATH"])
    asa_api_secret = SSMClient.new.get_parameter(ENV["ASA_API_SECRET_PATH"])

    uri = URI.parse("https://app.scaleft.com/v1/teams/#{ENV["ASA_TEAM"]}/service_token")
    data = { "key_id": asa_api_key.to_s,
             "key_secret": asa_api_secret.to_s }
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type': "application/json")
    request.body = data.to_json
    response = http.request(request)
    result = JSON.parse(response.body)
    @last_response = response.each_header
    result["bearer_token"]
  end

  def asa_api_query(path)
    result = []
    query_path = "https://app.scaleft.com/v1/teams/#{ENV["ASA_TEAM"]}/#{path}"
    loop do

      uri = URI.parse(query_path)
      header = { 'Content-Type': "application/json", 'Authorization': "Bearer #{asa_token}" }
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri, header)
      response = http.request(request)
      result += JSON.parse(response.body)["list"]
      @last_response = response.each_header

      break if response["link"].nil?

      link_header = LinkHeaderParser.parse(response["link"], base: "https://app.scaleft.com/v1/").first
      query_path = link_header.target_uri

      break if link_header.relations_string == "prev"
    end
    result
  end

  def asa_api_delete(path)
    uri = URI.parse("https://app.scaleft.com/v1/teams/#{ENV["ASA_TEAM"]}/#{path}")
    header = { 'Content-Type': "application/json", 'Authorization': "Bearer #{asa_token}" }
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Delete.new(uri.request_uri, header)
    response = http.request(request)
    @last_response = response.each_header
    response
  end
end
