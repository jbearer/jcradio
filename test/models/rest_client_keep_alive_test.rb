require 'test_helper'

# Covers config/initializers/rest_client_keep_alive.rb without touching the network:
# the connection's do_start is stubbed so no socket is opened.
class RestClientKeepAliveTest < ActiveSupport::TestCase
  # One pool per test so leftovers from another test cannot skew idle counts.
  def host
    @host ||= "keepalive-#{name.hash.abs.to_s(36)}.invalid"
  end

  def request(options = {})
    RestClient::Request.new({ method: :get, url: "https://#{host}/v1/test" }.merge(options))
  end

  def checkout
    http = request.send(:net_http_object, host, 443)
    http.define_singleton_method(:do_start) { @started = true }
    http
  end

  def idle_count
    JCRadio::HttpConnectionPool.idle_count(host, 443)
  end

  test "RestClient gets a pooled keep-alive connection and returns it after the request block" do
    first = checkout
    assert_kind_of JCRadio::KeepAliveHTTP, first
    assert_equal JCRadio::HttpConnectionPool::IDLE_LIMIT, first.keep_alive_timeout
    assert_equal 0, idle_count

    result = first.start { |http| assert_same first, http; :response }
    assert_equal :response, result
    assert first.started?
    assert_equal 1, idle_count

    second = request.send(:net_http_object, host, 443)
    assert_same first, second, 'the next request must reuse the open connection'
    assert_equal 0, idle_count
  end

  test "a connection checked out by one thread is not handed to another until returned" do
    held = checkout
    other = Thread.new { checkout }.value
    assert_not_same held, other
    held.start { }
    other.start { }
    assert_equal 2, idle_count
  end

  test "an exception inside the request block still returns the connection to the pool" do
    http = checkout
    assert_raises(RuntimeError) { http.start { raise 'boom' } }
    assert_equal 1, idle_count
    assert_same http, request.send(:net_http_object, host, 443)
  end

  test "a proxy configuration falls back to RestClient's own connection handling" do
    http = request(proxy: 'http://proxy.invalid:8080').send(:net_http_object, host, 443)
    assert_instance_of Net::HTTP, http
    assert_equal 0, idle_count
  end
end
