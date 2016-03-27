require "itcss_cli/version"
require "erb"
require 'fileutils'
require 'colorize'

module ItcssCli
  class Init

    ITCSS_DIR = "stylesheets"
    ITCSS_BASE_FILE = "application"
    ITCSS_MODULE_TEMPLATE = File.expand_path(File.join(File.dirname(__FILE__), "../templates/itcss_module.erb"))
    ITCSS_APP_TEMPLATE = File.expand_path(File.join(File.dirname(__FILE__), "../templates/itcss_application.erb"))
    ITCSS_FILES = ["settings", "tools", "generic", "base", "objects", "components", "trumps"]

    def command_parser
      # $ itcss init
      if ARGV[0] == 'init'


      # $ itcss install example
      elsif ARGV[0] == 'install' && ARGV[1] == 'example'
        new_itcss_basic_structure


      # $ itcss new components buttons
      elsif ARGV[0] == 'new' && ARGV[1] && ARGV[2]
        occur = ITCSS_FILES.each_index.select{|i| ITCSS_FILES[i].include? ARGV[1]}
        if occur.size == 1
          new_itcss_module(ITCSS_FILES[occur[0]], ARGV[2])
        end
      end

      # Enable ITCSS_BASE_FILE to import all itcss dependencies
      generate_base_file
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

      contents = "##{type}.#{file}"
      File.open "#{ITCSS_DIR}/#{type}/_#{type}.#{file}.sass", "w+" do |out|
        out.puts template.result binding
      end

      puts "create /#{type}/_#{type}.#{file}.sass".green
    end

    def generate_base_file
      itcss_files = Dir[ File.join(ITCSS_DIR, '**', '*') ].reject { |p| File.directory? p }

      File.open ITCSS_APP_TEMPLATE do |io|
        template = ERB.new io.read

        contents = "application.sass"
        File.open "#{ITCSS_DIR}/application.sass", "w+" do |out|
          out.puts template.result binding
        end
      end
    end

  end
end
