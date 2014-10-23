require 'socket'

class LogentriesOutput < Fluent::BufferedOutput
  class ConnectionFailure < StandardError; end
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('logentries', self)

  config_param :host, :string
  config_param :port, :integer, :default => 80
  config_param :tokens, :string

  def configure(conf)
    super
    @port   = conf['port']
    @host   = conf['host']
    @tokens = parse_tokens(conf['tokens'])
  end

  def parse_tokens(list)
    tokens_list = {}

    list.split(',').each do |host|
       key, token = host.split(':');
       tokens_list[key] = token
    end

    tokens_list
  end

  def start
    super
  end

  def shutdown
    super

    client.close
  end

  def client
    @_socket ||= TCPSocket.new @host, @port
  end

  def get_token(tag)
    @tokens.each do |key, value|
      if tag.index(key) != nil then
        return value
      end
    end

    return nil
  end

  # This method is called when an event reaches to Fluentd.
  def format(tag, time, record)
    token = get_token(tag)
    return [token, record].to_msgpack
  end

  # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
  def write(chunk)
    chunk.msgpack_each do |token, record|
      next unless record.is_a? Hash
      next if token.nil?

      if record.has_key?("message")
        send(record["message"] << ' ' << token)
      end
    end
  end

  def send(data)
    retries = 0
    begin
      client.puts data
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
      if retries < 2
        retries += 1
        @_socket = nil
        log.warn "Could not push logs to Logentries, resetting connection and trying again. #{e.message}"
        sleep 2**retries
        retry
      end
      raise ConnectionFailure, "Could not push logs to Logentries after #{retries} retries. #{e.message}"
    end
  end

end
