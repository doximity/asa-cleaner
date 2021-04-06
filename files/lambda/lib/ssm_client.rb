# frozen_string_literal: true

require "aws-sdk-ssm"
require "logger"

# Simple SSM client with throttling retry
class SSMClient
  def initialize
    @ssm_client = Aws::SSM::Client.new
  end

  def get_parameter(path)
    retries ||= 0
    resp = @ssm_client.get_parameter(
      name: path,
      with_decryption: true
    )
    resp.parameter.value
  rescue Aws::SSM::Errors::ThrottlingException => e
    raise e unless (retries += 1) <= 3

    log.warn({ message: "SSM #{path} throttled, retry ##{retries}", method: "get_parameter" })
    sleep retries
    retry
  end
end
