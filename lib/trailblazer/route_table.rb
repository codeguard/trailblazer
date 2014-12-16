require 'set'

module Trailblazer
  class RouteTable

    attr_reader :table, :vpc, :gateway

    def initialize(config)
      @logger = Logging.logger[self]
      raise "No route table declared in configuration! See `trailblazer -h`" unless config.route_table?
      @ec2 = AWS::EC2.new

      logger.debug "Retrieving route table information"
      @table = ec2.route_tables[config.route_table]
      @vpc = @table.vpc
      @gateway = @vpc.internet_gateway
    end

    def update(new_routes)
      logger.debug "Synchronizing with route table"
      changes = Hash.new {|h, k| h[k] = 0}
      destinations = Set.new
      table.routes.each do |route|
        dest, old_target = route.destination_cidr_block, route.target
        destinations.add dest
        if new_target = new_routes[dest]
          if new_target == old_target
            logger.debug "#{dest} -> #{old_target.id} : No change"
            changes[:unchanged] += 1
          else
            logger.warn "#{dest} -> #{old_target.id} : Replacing target with #{new_target.id}"
            route.replace target_option(new_target)
            changes[:replaced] += 1
          end
        # Special cases; don't delete the global route or default targets without replacing them
        elsif dest == '0.0.0.0/0' || old_target.id == 'local'
          logger.debug "#{dest} -> #{old_target.id} : Leaving default route unmodified"
          changes[:unchanged] += 1
        else
          logger.warn "#{dest} -> #{old_target.id} : Deleting unlisted route"
          route.delete
          changes[:deleted] += 1
        end
      end

      new_routes.each do |dest, target|
        unless destinations.include?(dest)
          logger.warn "#{dest} -> #{target.id} : Adding new route"
          table.create_route dest, target_option(target)
          changes[:added] += 1
        end
      end

      changes
    end

    private

    attr_reader :ec2, :logger

    def target_option(target)
      case target
      when AWS::EC2::InternetGateway
        {internet_gateway: target}
      when AWS::EC2::NetworkInterface
        {network_interface: target}
      when AWS::EC2::Instance
        {instance: target}
      end
    end
  end
end
