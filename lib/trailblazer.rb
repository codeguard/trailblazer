require 'aws-sdk'
require 'logging'
require 'pp'

require "trailblazer/version"
require 'trailblazer/config'
require 'trailblazer/route_table'
require 'trailblazer/routes'

module Trailblazer
  def self.execute
    config = Config.new
    configure_logger(config)
    configure_aws(config)

    logger.info "Starting route table update for #{config.route_table}"
    table = RouteTable.new(config)
    routes = Routes.new(config, table)
    changes = table.update(routes)
    logger.info "Update summary: #{changes}"
    logger.info "Finished route table update for #{config.route_table}"
  rescue => e
    logger.error e
  ensure
    send_sns(config.notification, config.route_table) if config.notification?
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

  def self.configure_logger(config)
    log = Logging.logger.root
    log.level = config.loglevel

    layout = Logging.layouts.pattern(pattern: "%d [%l] %m\n", date_pattern: '%Y-%m-%d %H:%M')
    appenders = [Logging.appenders.stdout(layout: layout)]

    if config.logfile?
      appenders << Logging.appenders.file('file', filename: config.logfile, layout: layout)
    end

    if config.notification?
      level = config.verbose ? :info : :warn
      appenders << Logging.appenders.string_io('sns', level: level, layout: layout)
    end

    log.add_appenders(*appenders)
  end

  def self.logger
    @logger ||= Logging.logger['MAIN']
  end

  def self.send_sns(arn, table)
    lines = Logging.appenders['sns'].sio
    message = lines.to_s
    if message.empty?
      logger.debug "SNS report is empty; not sending"
    else
      logger.debug "Publishing SNS report to #{arn}"
      sns = AWS::SNS.new
      topic = sns.topics[arn]
      topic.publish message, subject: "Route table update for #{table}"
    end
  rescue => e
    logger.error e
  end
end
