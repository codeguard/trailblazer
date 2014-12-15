require 'aws-sdk'

require "trailblazer/version"
require 'trailblazer/config'
require 'trailblazer/route_table'
require 'trailblazer/routes'

module Trailblazer
  def self.execute
    config = Config.new
    configure_aws(config)

    table = RouteTable.new(config)
    routes = Routes.new(config, table)
    changes = table.update(routes)
  end

  private

  # Set AWS access credentials if they were given on the command line or in the
  # config file. If they weren't, we'll just assume they're from IAM or the
  # environment.
  def self.configure_aws(config)
    if config.access_key? || config.secret_key?
      AWS.config access_key_id: config.access_key, secret_access_key: config.secret_key
    end
  end
end
