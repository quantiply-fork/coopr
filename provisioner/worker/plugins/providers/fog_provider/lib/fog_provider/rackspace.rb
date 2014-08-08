#!/usr/bin/env ruby
# encoding: UTF-8
#
# Copyright 2012-2014, Continuuity, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require_relative 'utils'

class FogProviderRackspace < Provider

  include FogProvider

  def create(inputmap)
    flavor = inputmap['flavor']
    image = inputmap['image']
    hostname = inputmap['hostname']
    fields = inputmap['fields']
    begin
      # Our fields are fog symbols
      fields.each do |k,v|
        instance_variable_set('@' + k, v)
      end
      # Create the server
      log.info "Creating #{hostname} on Rackspace using flavor: #{flavor}, image: #{image}"
      log.debug 'Invoking server create'
      begin
        server = connection.servers.create(
          :flavor_id    => flavor,
          :image_id     => image,
          :name         => hostname,
          :config_drive => @rackspace_config_drive || false,
          :metadata     => @rackspace_metadata,
          :disk_config  => @rackspace_disk_config || 'AUTO',
          :personality  => files,
          :key_name      => @rackspace_keyname
        )
        server.persisted? || server.save
      end
      # Process results
      @result['result']['providerid'] = server.id.to_s
      @result['result']['ssh-auth']['user'] = 'root'
      @result['result']['ssh-auth']['password'] = server.password unless server.password.nil?
      @result['result']['ssh-auth']['identityfile'] = @rackspace_keyfile unless @rackspace_keyfile.nil?
      @result['status'] = 0
    rescue Exception => e
      log.error('Unexpected Error Occurred in FogProviderRackspace.create:' + e.inspect)
      @result['stderr'] = "Unexpected Error Occurred in FogProviderRackspace.create: #{e.inspect}"
    else
      log.debug "Create finished successfully: #{@result}"
    ensure
      @result['status'] = 1 if @result['status'].nil? || (@result['status'].is_a?(Hash) && @result['status'].empty?)
    end
  end

  def confirm(inputmap)
    providerid = inputmap['providerid']
    fields = inputmap['fields']
    begin
      # Our fields are fog symbols
      fields.each do |k,v|
        instance_variable_set('@' + k, v)
      end
      # Confirm server
      log.debug "Invoking server confirm for id: #{providerid}"
      server = self.connection.servers.get(providerid)
      # Wait until the server is ready
      raise 'Server #{server.name} is in ERROR state' if server.state == 'ERROR'
      log.debug "waiting for server to come up: #{providerid}"
      server.wait_for(600) {
        if @rackconnect_wait
          ready? and metadata.all['rackconnect_automation_status'] == 'DEPLOYED'
        else
          ready?
        end
      }
      bootstrap_ip = ip_address(server, 'public')
      if bootstrap_ip.nil?
        log.error 'No IP address available for bootstrapping.'
      else
        log.debug "Bootstrap IP address #{bootstrap_ip}"
      end

      wait_for_sshd(bootstrap_ip, 22)
      log.debug "Server #{server.name} sshd is up"

      # Process results
      @result['result']['ipaddress'] = bootstrap_ip
      # Additional checks
      set_credentials(@task['config']['ssh-auth'])
      # Validate connectivity
      Net::SSH.start(@result['result']['ipaddress'], @task['config']['ssh-auth']['user'], @credentials) do |ssh|
        # Backwards-compatibility... ssh_exec! takes 2 arguments prior to 0.9.8
        ssho = method(:ssh_exec!)
        if ssho.arity == 2
          log.debug 'Validating external connectivity and DNS resolution via ping'
          ssh_exec!(ssh, 'ping -c1 www.opscode.com')
        else
          ssh_exec!(ssh, 'ping -c1 www.opscode.com', 'Validating external connectivity and DNS resolution via ping')
        end
      end
      # Return 0
      @result['status'] = 0
    rescue Fog::Errors::TimeoutError
      log.error 'Timeout waiting for the server to be created'
      @result['stderr'] = 'Timed out waiting for server to be created'
    rescue Net::SSH::AuthenticationFailed => e
      log.error("SSH Authentication failure for #{providerid}/#{@result['result']['ipaddress']}")
      @result['stderr'] = "SSH Authentication failure for #{providerid}/#{@result['result']['ipaddress']}: #{e.inspect}"
    rescue Exception => e
      log.error('Unexpected Error Occurred in FogProviderRackspace.confirm:' + e.inspect)
      @result['stderr'] = "Unexpected Error Occurred in FogProviderRackspace.confirm: #{e.inspect}"
    else
      log.debug "Confirm finished successfully: #{@result}"
    ensure
      @result['status'] = 1 if @result['status'].nil? || (@result['status'].is_a?(Hash) && @result['status'].empty?)
    end
  end

  def delete(inputmap)
    providerid = inputmap['providerid']
    fields = inputmap['fields']
    begin
      # Our fields are fog symbols
      fields.each do |k,v|
        instance_variable_set('@' + k, v)
      end
      # Delete server
      log.debug 'Invoking server delete'
      begin
        server = self.connection.servers.get(providerid)
        server.destroy
      rescue NoMethodError
        log.warn "Could not locate server '#{providerid}'... skipping"
      end
      # Return 0
      @result['status'] = 0
    rescue => e
      log.error('Unexpected Error Occurred in FogProviderRackspace.delete:' + e.inspect)
      @result['stderr'] = "Unexpected Error Occurred in FogProviderRackspace.delete: #{e.inspect}"
    else
      log.debug "Delete finished sucessfully: #{@result}"
    ensure
      @result['status'] = 1 if @result['status'].nil? || (@result['status'].is_a?(Hash) && @result['status'].empty?)
    end
  end

  # Shared definitions (borrowed from knife-rackspace gem, Apache 2.0 license)

  def connection
    log.debug "Connection options for Rackspace:"
    log.debug "- rackspace_api_key #{@rackspace_api_key}"
    log.debug "- rackspace_username #{@rackspace_username}"
    log.debug "- rackspace_region #{@rackspace_region}"
    log.debug "- rackspace_auth_url #{auth_endpoint}"

    # Create connection
    @connection ||= begin
      connection = Fog::Compute.new(
        :provider => 'Rackspace',
        :version  => 'v2',
        :rackspace_username => @rackspace_username,
        :rackspace_api_key  => @rackspace_api_key,
        :rackspace_region   => @rackspace_region,
        :rackspace_auth_url => auth_endpoint
      )
    end
  end

  def parse_file_argument(arg)
    dest, src = arg.split('=')
    unless dest && src
      log.error "Unable to process file arguments #{arg}. The remote destination and local source using DESTINATION-PATH=SOURCE-PATH are needed"
      raise "Failed processing file arguments #{arg}"
    end
    [dest, src]
  end

  def encode_file(file)
    begin
      filename = File.expand_path(file)
      content = File.read(filename)
    rescue Errno::ENOENT => e
      log.error("Unable to read source file - #{filename}" + e.inspect)
      raise "Failed encoding file #{filename} - #{e.inspect}"
    end
    Base64.encode64(content)
  end

  def files
    return {} unless @rackspace_files

    files = []
    @rackspace_files.each do |arg|
      dest, src = parse_file_argument(arg)
      Chef::Log.debug("Inject file #{src} into #{dest}")
      files << {
        :path => dest,
        :contents => encode_file(src)
      }
    end
    files
  end

  def auth_endpoint
    url = @rackspace_auth_url if @rackspace_auth_url
    return url if url
    (@rackspace_region == 'lon') ? ::Fog::Rackspace::UK_AUTH_ENDPOINT : ::Fog::Rackspace::US_AUTH_ENDPOINT
  end

  def ip_address(server, network = 'public')
    if network == 'public' && v2_access_ip(server) != ''
      v2_access_ip(server)
    else
      v2_ip_address(server, network)
    end
  end

  def v2_ip_address(server, network)
    network_ips = server.addresses[network]
    extract_ipv4_address(network_ips) if network_ips
  end

  def v2_access_ip(server)
    server.access_ipv4_address.nil? ? '' : server.access_ipv4_address
  end

  def extract_ipv4_address(ip_addresses)
    address = ip_addresses.select { |ip| ip['version'] == 4 }.first
    address ? address['addr'] : ''
  end

end
