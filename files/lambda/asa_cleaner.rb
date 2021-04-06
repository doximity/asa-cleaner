# frozen_string_literal: true

require "logger"

require_relative "lib/cleaner"
require_relative "lib/ssm_client"

def lambda_handler(event:, context:)
  logger.info "Lambda execution info: #{context.inspect}"
  Cleaner.new(event["detail"]["instance-id"]).run
end
