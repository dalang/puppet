#!/usr/bin/env ruby

require 'fileutils'
require 'win32/daemon'
require 'win32/dir'
require 'win32/process'
require 'open3'

require 'windows/synchronize'
require 'windows/handle'

class WindowsDaemon < Win32::Daemon
  include Windows::Synchronize
  include Windows::Handle
  include Windows::Process

  LOG_FILE =  File.expand_path(File.join(Dir::COMMON_APPDATA, 'PuppetLabs', 'puppet', 'var', 'log', 'windows.log'))
  LEVELS = [:debug, :info, :notice, :err]
  LEVELS.each do |level|
    define_method("log_#{level}") do |msg|
      log(msg, level)
    end
  end

  def service_init
    FileUtils.mkdir_p(File.dirname(LOG_FILE))
  end

  def service_main(*argv)
    args = argv.join(' ')
    @loglevel = LEVELS.index(argv.index('--debug') ? :debug : :notice)

    log_notice("Starting service: #{args}")

    while running? do
      return if state != RUNNING

      log_notice('Service running')

      basedir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
      puppet = File.join(basedir, 'bin', 'puppet.bat')
      unless File.exists?(puppet)
        log_err("File not found: '#{puppet}'")
        return
      end

      if File.exists?(file_path = 'c:\ProgramData\PuppetLabs\puppet\razor\puppetboot.bat')
        sleep(180) # delay to ensure network is enabled
        open3_exec(file_path) { %x( ren #{file_path} *?.done ) }
      end

      if File.exists?(file_path = 'c:\razor_puppet.pp')
        command = "\"#{puppet}\" apply #{file_path}"
        open3_exec(command) { %x( del #{file_path} && shutdown -r -t 00 ) }
        sleep(60) # waiting for execution of `shutdown`
      end

      log_debug("Using '#{puppet}'")
      begin
        runinterval = %x{ "#{puppet}" agent --configprint runinterval }.to_i
        if runinterval == 0
          runinterval = 900
          log_err("Failed to determine runinterval, defaulting to #{runinterval} seconds")
        end
      rescue Exception => e
        log_exception(e)
        runinterval = 900
      end

      server = %x{ "#{puppet}" agent --configprint server }
      server.strip!
      stdout, stderr, status = Open3.capture3("net time \\\\#{server} /set /y")

      log_debug("sync time: #{stdout}")
      if status.success?
        log_notice("Sync Time with Server: [#{server}] succeed")
      else
        log_err("Sync Time with Server [#{server}] failed: #{stderr}")
      end

      pid = Process.create(:command_line => "\"#{puppet}\" agent --onetime #{args}", :creation_flags => Process::CREATE_NEW_CONSOLE).process_id
      log_debug("Process created: #{pid}")

      log_debug("Service waiting for #{runinterval} seconds")
      sleep(runinterval)
      log_debug('Service resuming')
    end

    log_notice('Service stopped')
  rescue Exception => e
    log_exception(e)
  end

  def service_stop
    log_notice('Service stopping')
    Thread.main.wakeup
  end

  def open3_exec(command)
      begin
        log_notice("try to run [#{command}] via Open3")
        stdout, stderr, status = Open3.capture3(command)
        log_notice("stdout: #{stdout}")
        if status.success?
          log_notice("[#{command}]: succeed")
          yield if block_given?
        else
          log_err("[#{command}] failed: #{stderr}")
        end
      rescue => e
        log_err("open3 error: #{e.message}")
      end
  end

  def log_exception(e)
    log_err(e.message)
    log_err(e.backtrace.join("\n"))
  end

  def log(msg, level)
    if LEVELS.index(level) >= @loglevel
      File.open(LOG_FILE, 'a') { |f| f.puts("#{Time.now} Puppet (#{level}): #{msg}") }
    end
  end
end

if __FILE__ == $0
  WindowsDaemon.mainloop
end
