#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'net/ssh'

@F, @V = "remex.rb", "0.1"

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
    puts "  #{@F} -a 'root:pass' -H '192.168.1.101,192.168.1.119' -c 'uptime'"
    exit
  end
end
optparse.parse!

def err(t) puts "Error: #{t}"; exit; end
def v(t) puts "Info: #{t}" if @opts[:verbose]; end

err "No hosts arg" if !@opts[:hosts]
err "No cmd arg"   if !@opts[:cmd]
err "No auth arg"  if !@opts[:auth]

def remex(hosts, cmd, auth)
  puts "remex:"
  puts "  hosts: #{hosts.inspect}"
  puts "  cmd: #{cmd.inspect}"
  puts "  auth: #{auth.inspect}"
  Thread.abort_on_exception = true
  threads = []
  user, pass = auth.split ':'
  hosts.each { |h|
    threads << Thread.new("t_#{h}") {
      v "Otvaram SSH konekciju na '#{h}'"
      Net::SSH.start(h, user, :password => pass) do |ssh|
        result = ssh.exec!(cmd)
        puts result
      end
      v "Zatvaram '#{h}'"
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
        collect {|a| @opts[:hosts][/^\d+\.\d+\.\d+\./] + a}
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

remex(parse_hosts(), @opts[:cmd], @opts[:auth])
