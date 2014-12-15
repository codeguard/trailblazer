# Trailblazer

A route table maintenance utility for VPC subnets that want *most* Internet traffic behind a NAT, but want direct access to Amazon AWS services. Given a route table as the single required parameter, it downloads the latest [IP Ranges JSON file](https://ip-ranges.amazon.com/ip-ranges.json) and directs any CIDR blocks in the VPC's region to the VPC's internet gatweay. Other routes of importance may be registered via command line options or a configuration YAML file.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'trailblazer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install trailblazer

## Usage

The `trailblazer` utility is best run as a *cron* job or other scheduled task. A weekly run is probably sufficient, given the low frequency of Amazon updates to their range list. Options can be passed via the command line or configuration file (see below).  *At minimum* you must identify the routing table to update and any custom routes to retain after synchronizing the AWS ranges.

When run, `trailblazer` replaces the contents of the specified routing table as follows:

* The Amazon **ip-ranges.json** file is downloaded and its entries are filtered to only the configured regions and services:
** The default regions are *GLOBAL* and *us-east-1*.
** The default service is *AMAZON*. Consider adding *EC2* if instances inside the VPC need to communicate frequently with instances outside the VPC (including EC2-hosted Amazon services such as RDS).
* The IP ranges passing the filter are matched to the configured target and merged with specified custom routes.
** The default target for IP ranges is the *gateway* special value, which refers to the VPC's Internet gateway.
* The contents of the routing table are compared to the merged list and altered as necessary.
** Routes from the routing table that are not present in the merged list are deleted.
** Routes from the merged list that are not present in the routing table are added.
** As a safety measure, an existing route matching `0.0.0.0/0` will be left alone unless explicitly overridden with a different target.
* The route table is tagged with metadata to report status and prevent unnecessary work on the next sync round:
** *last_synced_at* - The timestamp at completion.
** *last_updated_at* - The timestamp of the last time the route table was changed.
** *ip_range_token* - The sync token from the current **ip-ranges.json** file.
** *custom_route_hash* - Hash value of the current custom routes (if any).
* If a notification topic was configured, a report is sent summarizing changes.


### Config File
With no parameters, `trailblazer` will look for a configuration file at **~/.trailblazer.yml**. The file should have a **route_table** key at minimum unless the route table is passed on the command line. An example configuration follows:

```yaml
# The one required parameter. Specify Amazon's canonical ID for the route table to update.
# (The VPC and other related resources can be inferred from the table.)
route_table: rtb-a87b92e3

# Credentials for Amazon Web Services. If not specified, the environment variables
# AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY will be used, or IAM role metadata.
aws:
  access_key_id: AKIAIABX3KKR4VHCHPGB
  secret_access_key: eAQXj6cGbw0FiMs0xZMt6fxqnMFwcZXoHy1K+y7Y

# These values refer to Amazon's IP Ranges JSON file. All values given in this example
# are the defaults.
ip_ranges:
  # Link to JSON file containing IP blocks to route. If overridden, the custom file
  # must include the 'createDate' and 'prefixes' top-level keys.
  url: https://ip-ranges.amazonaws.com/ip-ranges.json

  # The target to which the IP blocks from the ip-ranges.json file should be routed.
  # Should be an IP address, an Amazon resource ID (instance, network interface, or
  # gateway), or the special value 'gateway', which uses the owning VPC's Internet
  # gateway.
  target: gateway

  # The ranges from the ip-ranges.json file to include in the route table.
  # Defaults to 'GLOBAL' and 'us-east-1'. Note that including too many regions
  # may break the size limit of your routing table (50 routes unless a limit
  # increase is requested).
  regions:
    - us-east-1
    - GLOBAL

  # The ranges from the ip-ranges.json file to include in the route table.
  # Defaults to 'AMAZON'. Note that including too many services
  # may break the size limit of your routing table (50 routes unless a limit
  # increase is requested).
  services:
    - AMAZON

# Custom routes to add to the table. It is *highly* recommended to at least
# add a default route forwarding 0.0.0.0/0 to your NAT instance.
routes:
  # Each key specifies a routing target. Values may be a single CIDR block
  # or an array of same.

  # NAT instance; default route
  0.0.0.0/0: i-8422ea95

  # The special value 'gateway' specifies the owning
  # VPC's Internet gateway.
  54.231.99.21: gateway    # RDS instance (example)
  22.94.331.0/24: gateway  # Home network (example)

# If configured, trailblazer will send reports to the given SNS topic
# (eliminating the need for a persistent log file).
notification:
  # Amazon's canonical ARN for the SNS topic.
  topic: arn:aws:sns:us-east-1:1234567890123456:mytopic

  # If true, trailblazer will send a report on every run.
  # If false (the default), reports are only sent on errors or when the route table is changed.
  verbose: true
```

### Command Line Options

# `-c config.yml`, `--config config.yml`: Specify a filepath or URL for configuration YAML file. Defaults to **~/.trailblazer.yml**.
* `-t id`, `--route-table id`: Canonical ID for the route table to update.
* `-r CIDR=target`, `--route CIDR=target`: Custom routes. May be specified multiple times.
* `--ip-target target`: Target for routes from ip-ranges list. Defaults to *gateway*.
* `--ip-url url`: Location of ip-ranges.json list. Defaults to 'https://ip-ranges.amazon.com/ip-ranges.json'.
* `--ip-region region`: Region filter for ip-ranges list. May be specified multiple times.
* `--ip-service service`: Service filter for ip-ranges list. May be specified multiple times.
* `-n`, `--notification`: SNS topic ARN for run results.
* `-v`, `--verbose`: Send a report on every run.



## Contributing

1. Fork it ( https://github.com/[my-github-username]/trailblazer/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
