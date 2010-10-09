#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'net/ssh'

@F, @V = "remex.rb", "0.2"

@opts = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: remex.rb [options]"

  @opts[:hosts] = nil
  opts.on( '-H', '--hosts HOSTS', 'Host file ili range' ) do |str|
    @opts[:hosts] = str
  end

  @opts[:cmd] = nil
  opts.on( '-c', '--cmd CMD', 'Remote command' ) do |cmd|
    @opts[:cmd] = cmd
  end

  @opts[:auth] = nil
  opts.on( '-a', '--auth CREDS', 'SSH username i password (user:pass)' ) do |a|
    @opts[:auth] = a
  end

  @opts[:timeout] = nil
  opts.on( '-t', '--timeout SECS', 'Conn. Timeout (s)' ) do |t|
    @opts[:timeout] = t
  end

  @opts[:verbose] = nil
  opts.on( '-v', '--verbose', 'Debug ispis' ) do
    @opts[:verbose] = true
  end

  opts.on( '-h', '--help', 'Ovaj output' ) do
    puts "#{@F} v#{@V}"
    puts opts
    puts "Primjeri:"
    puts "  #{@F} -a 'root:pass' -H 192.168.1.1 -c 'uptime'"
    puts "  #{@F} -a 'root:pass' -H '192.168.1.1,192.168.1.2' -c 'uptime'"
    puts "  #{@F} -a 'root:pass' -H '192.168.1.101-119' -c 'uptime' -t 10"
    puts "  #{@F} -a 'root:pass' -H hostovi.txt -c 'uptime' -t 10"
    exit
  end
end
optparse.parse!

def err(t) puts "Error: #{t}"; exit; end
def v(t) puts "Info: #{t}" if @opts[:verbose]; end

err "No hosts arg" if !@opts[:hosts]
err "No cmd arg"   if !@opts[:cmd]
err "No auth arg"  if !@opts[:auth]

v [
  "ARGS:",
  "  hosts: #{@opts[:hosts]}",
  "  cmd:   #{@opts[:cmd]}",
  "  auth:  #{@opts[:auth]}"
].join "\n"

def remex(hosts, cmd, auth, timeout=10)
  v [
    "remex:",
    "  hosts: #{hosts.inspect}",
    "  cmd:   #{cmd.inspect}",
    "  auth:  #{auth.inspect}"
  ].join "\n"
  Thread.abort_on_exception = true
  threads = []
  user, pass = auth.split ':'
  hosts.each { |h|
    threads << Thread.new("t_#{h}") {
      v "CONN '#{h}'"
      begin
        Net::SSH.start(h, user, :password => pass, :timeout => timeout) do |ssh|
          result = ssh.exec!(cmd) do |channel, success|
            unless success
              abort "#{h}: CMD FAILED (ssh.channel.exec failure)"
            end
            channel.on_data do |ch, data| # stdout
              puts "#{h}: DATA:"
              puts data
              puts "END DATA"
            end
            channel.on_extended_data do |ch, type, data|
              next unless type == 1 # stderr
              # $stderr.print data
            end
            channel.on_request("exit-status") do |ch, data|
              exit_code = data.read_long
              if exit_code > 0
                puts "#{h}: EXIT #{exit_code}"
              else
                puts "#{h}: OK"
              end
            end
            channel.on_request("exit-signal") do |ch, data|
              puts "#{h}: SIGNAL #{data.read_long}"
            end
          end
          # puts result
        end
        v "CLOSE '#{h}'"
      rescue Timeout::Error
        v "TLE '#{h}'"
      rescue Errno::EHOSTDOWN
        v "DOWN '#{h}'"
      rescue
        v "ERR '#{h}'"
      end
    }
  }
  threads.each {|t| t.join}
  return true
end

def parse_hosts()
  hosts = []
  case @opts[:hosts]
    when /^\d+\.\d+\.\d+\.\d+\-\d+$/ # 192.168.0.101-129
      # Range.new *("1.2.3.4-5"[/\d+\-\d+$/].split('-').map{|x|x.to_i}) => 4..5
      hosts =
        Range.new(*(@opts[:hosts][/\.(\d+\-\d+)$/, 1].split('-').map{|x| x.to_i})).
        collect {|a| "#{@opts[:hosts][/^\d+\.\d+\.\d+\./]}#{a}"}
    when /^\d+\.\d+\.\d+\.\d+$/ # 192.168.0.123
      hosts << @opts[:hosts]
    when /^.+(\,|\ ).+$/ # 1.2.3.4,1.2.3.5
      hosts = @opts[:hosts].split(/\,\ |\,|\ /)
    else # filename sa hostovima
      if File.exist? @opts[:hosts]
        hosts = File.readlines(
          File.expand_path(@opts[:hosts])
        ).collect {|x| x[/(.+)\n$/, 1] if x!="\n"}.compact
      else
        err "Krivi hosts arg!"
      end
  end
  return hosts
end

remex(parse_hosts(), @opts[:cmd], @opts[:auth], @opts[:timeout].to_i)
