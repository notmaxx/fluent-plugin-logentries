require 'socket'
require 'yaml'
require 'openssl'

class Fluent::LogentriesOutput < Fluent::BufferedOutput
  class ConnectionFailure < StandardError; end
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('logentries-simple-config', self)

  config_param :use_ssl,        :bool,    :default => true
  config_param :use_json,       :bool,    :default => false
  config_param :port,           :integer, :default => 20000
  config_param :protocol,       :string,  :default => 'tcp'
  config_param :token,          :string
  config_param :max_retries,    :integer, :default => 3

  SSL_HOST    = "api.logentries.com"
  NO_SSL_HOST = "data.logentries.com"
  HOSTNAME    = `hostname`.strip

  def configure(conf)
    super

    @tokens    = nil
    @last_edit = Time.at(0)
  end

  def start
    super
  end

  def shutdown
    super
  end

  def client
    @_socket ||= if @use_ssl
      context    = OpenSSL::SSL::SSLContext.new
      socket     = TCPSocket.new SSL_HOST, @port
      ssl_client = OpenSSL::SSL::SSLSocket.new socket, context

      ssl_client.connect
    else
      if @protocol == 'tcp'
        TCPSocket.new NO_SSL_HOST, @port
      else
        udp_client = UDPSocket.new
        udp_client.connect NO_SSL_HOST, @port

        udp_client
      end
    end
  end

  # This method is called when an event reaches Fluentd.
  def format(tag, time, record)
    return [tag, record].to_msgpack
  end

  # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
  def write(chunk)
    generate_tokens_list()
    return if @token.blank?

    chunk.msgpack_each do |tag, record|
      next unless record.is_a? Hash
      next unless @use_json or record.has_key? "message"

      # Clean up the string to avoid blank line in logentries
      message = @use_json ? record.to_json : record["message"].rstrip()
      send_logentries(@token, message)
    end
  end

  def send_logentries(token, data)
    retries = 0
    begin
      client.write("#{token} #{HOSTNAME} #{data} \n")
    rescue Errno::EMSGSIZE
      str_length = data.length
      send_logentries(token, data[0..str_length/2])
      send_logentries(token, data[(str_length/2)+1..str_length])

      log.warn "Message Too Long, re-sending it in two part..."
    rescue => e
      if retries < @max_retries
        retries += 1
        @_socket = nil
        log.warn "Could not push logs to Logentries, resetting connection and trying again. #{e.message}"
        sleep 5**retries
        retry
      end
      raise ConnectionFailure, "Could not push logs to Logentries after #{retries} retries. #{e.message}"
    end
  end

end
