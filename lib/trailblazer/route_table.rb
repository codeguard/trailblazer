require 'set'

module Trailblazer
  class RouteTable

    attr_reader :table, :vpc, :gateway

    def initialize(config)
      abort "No route table declared in configuration! See `trailblazer -h`" unless config.route_table?
      @ec2 = AWS::EC2.new
      @table = ec2.route_tables[config.route_table]
      @vpc = @table.vpc
      @gateway = @vpc.internet_gateway
    end

    def update(new_routes)
      deleted, replaced, added, unchanged = {}, {}, {}, {}
      destinations = Set.new
      table.routes.each do |route|
        dest, old_target = route.destination_cidr_block, route.target
        destinations.add dest
        if new_target = new_routes[dest]
          if new_target == old_target
            unchanged[dest] = old_target
          else
            replaced[dest] = {old: old_target, new: new_target}
            route.replace target_option(new_target)
          end
        # Special cases; don't delete the global route or default targets without replacing them
        elsif dest == '0.0.0.0/0' || old_target.id == 'local'
          unchanged[dest] = old_target
        else
          deleted[dest] = old_target
          route.delete
        end
      end

      pp new_routes.routes
      new_routes.each do |dest, target|
        unless destinations.include?(dest)
          added[dest] = target
          table.create_route dest, target_option(target)
        end
      end

      {
        deleted: deleted,
        replaced: replaced,
        added: added,
        unchanged: unchanged
      }
    end

    private

    attr_reader :ec2

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
