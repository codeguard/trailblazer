require 'delegate'
require 'open-uri'
require 'json'
require 'pp'

module Trailblazer
  class Routes < DelegateClass(Hash)

    attr_reader :routes, :route_table

    def initialize(config, route_table)
      @ec2 = AWS::EC2.new
      @ranges = range_list(config.ip_url)
      filter_regions(*config.ip_regions) unless config.ip_regions.empty?
      filter_services(*config.ip_services) unless config.ip_services.empty?
      untargeted_routes = target_ranges(config.ip_target).merge(config.routes)
      @routes = find_targets(untargeted_routes, route_table.gateway)
      super(routes)
    end

    private

    attr_reader :ranges, :ec2

    def range_list(url)
      open(url) do |file|
        data = JSON.parse(file.read)
        data['prefixes']
      end
    end

    def filter_regions(*regions)
      ranges.delete_if {|r| !regions.include?(r['region'])}
    end

    def filter_services(*services)
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
