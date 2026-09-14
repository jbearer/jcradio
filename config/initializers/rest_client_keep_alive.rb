# RestClient (RSpotify's transport) opens a new TCP+TLS connection for every Spotify call.
# Measured on the Pi: ~280 ms per call, ~205 ms of it DNS+TCP+TLS handshake; a warm
# connection does the same request in ~70 ms. RestClient::Request wraps each request in
# `net.start { ... }` on the object returned by #net_http_object, so hand it a pooled
# Net::HTTP whose #start keeps the socket open and returns it to the pool afterwards.
# Net::HTTP reconnects by itself when the socket is closed, when the server already sent
# FIN, or after keep_alive_timeout idle seconds. script/perf/spotify-idle-probe.py showed
# api.spotify.com still serving a reused connection after 180 s idle, so 60 s is conservative.
# GET/PUT are retried once by Net::HTTP on a dead socket; POST is not, see station.rb.
require "net/http"
require "rest-client"

module JCRadio
  module HttpConnectionPool
    IDLE_LIMIT = 60 # seconds

    @pools = Hash.new { |hash, key| hash[key] = Queue.new }
    @lock = Mutex.new

    def self.checkout(hostname, port)
      pool = @lock.synchronize { @pools["#{hostname}:#{port}"] }
      pool.pop(true)
    rescue ThreadError # pool empty
      http = KeepAliveHTTP.new(hostname, port)
      http.keep_alive_timeout = IDLE_LIMIT
      http
    end

    def self.checkin(http)
      pool = @lock.synchronize { @pools["#{http.address}:#{http.port}"] }
      pool.push(http)
    end

    def self.idle_count(hostname, port)
      @lock.synchronize { @pools["#{hostname}:#{port}"].size }
    end
  end

  class KeepAliveHTTP < Net::HTTP
    def start
      do_start unless started?
      return self unless block_given?
      begin
        yield self
      ensure
        HttpConnectionPool.checkin(self)
      end
    end
  end

  module RestClientKeepAlive
    def net_http_object(hostname, port)
      return super unless proxy_uri.nil?
      HttpConnectionPool.checkout(hostname, port)
    end
  end
end

RestClient::Request.prepend JCRadio::RestClientKeepAlive
