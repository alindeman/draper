require 'capybara'
require 'capybara/dsl'
require 'capybara/poltergeist'
require 'singleton'
require 'socket'

# Adapted from code by Jon Leighton
# https://github.com/jonleighton/focused_controller/blob/ec7ccf1/test/acceptance/app_test.rb

Capybara.run_server = false
Capybara.default_driver = :poltergeist

class DummyApp

  def initialize(environment)
    @environment = environment
  end

  def url
    "http://#{localhost}:#{port}"
  end

  def within_app(&block)
    Dir.chdir(root, &block)
  end

  def start_server
    within_app do
      IO.popen("bundle exec rails s -e #{@environment} -p #{port} 2>&1") do |out|
        start   = Time.now
        started = false
        output  = ""
        timeout = 60.0

        while !started && !out.eof? && Time.now - start <= timeout
          output << read_output(out)
          sleep 0.1

          begin
            TCPSocket.new(localhost, port)
          rescue Errno::ECONNREFUSED
          else
            started = true
          end
        end

        raise "Server failed to start:\n#{output}" unless started

        yield

        Process.kill('KILL', out.pid)
      end
    end
  end

  private

  def root
    File.expand_path('../../dummy', __FILE__)
  end

  def localhost
    '127.0.0.1'
  end

  def port
    @port ||= begin
      server = TCPServer.new(localhost, 0)
      port   = server.addr[1]
    ensure
      server.close if server
    end
  end

  def read_output(stream)
    read = IO.select([stream], [], [stream], 0.1)
    output = ""
    loop { output << stream.read_nonblock(1024) } if read
    output
  rescue Errno::EAGAIN, Errno::EWOULDBLOCK, EOFError
    output
  end
end
