require 'delegate'
require 'open-uri'
require 'json'
require 'pp'

module Trailblazer
  class Routes < DelegateClass(Hash)

    attr_reader :routes, :route_table

    def initialize(config, route_table)
      @logger = Logging.logger[self]
      @ec2 = AWS::EC2.new
      @ranges = range_list(config.ip_url)
      filter_regions(*config.ip_regions) unless config.ip_regions.empty?
      filter_services(*config.ip_services) unless config.ip_services.empty?

      logger.debug do
        str = "Loading custom routes:\n"
        config.routes.each { |dest, target| str << "  #{dest} -> #{target}\n" }
        str
      end

      untargeted_routes = target_ranges(config.ip_target).merge(config.routes)
      @routes = find_targets(untargeted_routes, route_table.gateway)
      super(routes)
    end

    private

    attr_reader :ranges, :ec2, :logger

    def range_list(url)
      logger.debug "Retrieving IP ranges list from #{url}"
      open(url) do |file|
        data = JSON.parse(file.read)
        data['prefixes']
      end
    end

    def filter_regions(*regions)
      logger.debug "Filtering IP ranges by region: #{regions.join(', ')}"
      ranges.delete_if {|r| !regions.include?(r['region'])}
    end

    def filter_services(*services)
      logger.debug "Filtering IP ranges by service: #{services.join(', ')}"
      ranges.delete_if {|r| !services.include?(r['service'])}
    end

    def target_ranges(target)
      hash = {}
      ranges.each { |range| hash[range['ip_prefix']] = target }
      hash
    end

    # Replace 'gateway' and various IDs with the actual objects
    def find_targets(untargeted, gateway)
      targeted = {}
      untargeted.each do |dest, name|
        target = case name
        when 'gateway'
          gateway
        when /^i-/
          ec2.instances[name]
        when /^igw-/
          ec2.internet_gateways[name]
        when /^eni-/
          ec2.network_interfaces[name]
        end
        targeted[dest] = target
      end
      targeted
    end

  end
end
