require "itcss_cli/version"
require "erb"
require 'fileutils'
require 'colorize'
require 'yaml'

module ItcssCli
  class Init

    ITCSS_CONFIG_FILE = 'itcss.yml'
    ITCSS_CONFIG_TEMPLATE = File.expand_path(File.join(File.dirname(__FILE__), "../templates/itcss_config.erb"))
    ITCSS_MODULE_TEMPLATE = File.expand_path(File.join(File.dirname(__FILE__), "../templates/itcss_module.erb"))
    ITCSS_APP_TEMPLATE = File.expand_path(File.join(File.dirname(__FILE__), "../templates/itcss_application.erb"))
    ITCSS_FILES = ["settings", "tools", "generic", "base", "objects", "components", "trumps"]

    if File.exist?(ITCSS_CONFIG_FILE)
      ITCSS_CONFIG = YAML.load_file(ITCSS_CONFIG_FILE)
      ITCSS_CONFIG['stylesheets_directory'].nil? ? ITCSS_DIR = nil : ITCSS_DIR = ITCSS_CONFIG['stylesheets_directory']
      ITCSS_CONFIG['stylesheets_import_file'].nil? ? ITCSS_BASE_FILE = nil : ITCSS_BASE_FILE = ITCSS_CONFIG['stylesheets_import_file']
    else
      ITCSS_CONFIG = nil
    end

    def init_checker
      if ITCSS_CONFIG.nil?
        puts "There's no #{ITCSS_CONFIG_FILE} created yet. Run `itcss init` to create it.".red
        abort
      end
    end

    def command_parser
      # $ itcss init
      if ARGV[0] == 'init'
        init_itcss_config_file


      # $ itcss install example
      elsif ARGV[0] == 'install' && ARGV[1] == 'example'
        init_checker
        new_itcss_basic_structure


      # $ itcss new components buttons
      elsif ARGV[0] == 'new' && ARGV[1] && ARGV[2]
        init_checker

        occur = ITCSS_FILES.each_index.select{|i| ITCSS_FILES[i].include? ARGV[1]}
        if occur.size == 1
          new_itcss_module(ITCSS_FILES[occur[0]], ARGV[2])
        else
          puts "'#{ARGV[1]}' is not an ITCSS module. Try settings, tools, generic, base, objects, components or trumps.".red
          abort
        end

      # $ itcss update
      elsif ARGV[0] == 'install' || ARGV[0] == 'new' || ARGV[0] == 'update'
        generate_base_file
      end
    end

    def init_itcss_config_file
      unless File.exist?(ITCSS_CONFIG_FILE)
        File.open ITCSS_CONFIG_TEMPLATE do |io|
          template = ERB.new io.read

          File.open ITCSS_CONFIG_FILE, "w+" do |out|
            out.puts template.result binding
          end
        end
        puts "create #{ITCSS_CONFIG_FILE}".green
      else
        puts "#{ITCSS_CONFIG_FILE} already exists.".red
        abort
      end
    end

    def new_itcss_basic_structure
      File.open ITCSS_MODULE_TEMPLATE do |io|
        template = ERB.new io.read

        ITCSS_FILES.each do |file|
          new_itcss_file(file, 'example', template)
        end
      end
    end

    def new_itcss_module(type, file)
      File.open ITCSS_MODULE_TEMPLATE do |io|
        template = ERB.new io.read
        new_itcss_file(type, file, template)
      end
    end

    def new_itcss_file(type, file, template)
      FileUtils.mkdir_p ITCSS_DIR
      FileUtils.mkdir_p "#{ITCSS_DIR}/#{type}"

      unless File.exist?("#{ITCSS_DIR}/#{type}/_#{type}.#{file}.sass")
        contents = "##{type}.#{file}"
        File.open "#{ITCSS_DIR}/#{type}/_#{type}.#{file}.sass", "w+" do |out|
          out.puts template.result binding
        end
        puts "create /#{type}/_#{type}.#{file}.sass".green
      else
        puts "/#{type}/_#{type}.#{file}.sass is already created. Please delete it if you want it to be rewritten.".red
        abort
      end
    end

    def generate_base_file
      itcss_files = Dir[ File.join(ITCSS_DIR, '**', '*') ].reject { |p| File.directory? p }

      File.open ITCSS_APP_TEMPLATE do |io|
        template = ERB.new io.read

        contents = "#{ITCSS_BASE_FILE}.sass"
        File.open "#{ITCSS_DIR}/#{ITCSS_BASE_FILE}.sass", "w+" do |out|
          out.puts template.result binding
        end
      end

      puts "update #{ITCSS_BASE_FILE}.sass".blue
    end

  end
end
