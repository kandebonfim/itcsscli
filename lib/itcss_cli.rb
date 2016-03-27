require "itcss_cli/version"
require "erb"
require 'fileutils'

module ItcssCli
  class Init

    ITCSS_DIR = "stylesheets"
    ITCSS_FILE_TEMPLATE = File.expand_path(File.join(File.dirname(__FILE__), "../templates/itcss_file.erb"))

    def command
      ARGV.each do |arg|

        File.open ITCSS_FILE_TEMPLATE do |io|
          template = ERB.new io.read

          files = {
            "settings" => "#settings.example",
            "components" => "#components.example"
          }

          FileUtils.mkdir_p ITCSS_DIR

          files.each do |file, contents|
            File.open "#{ITCSS_DIR}/#{file}.#{file}.sass", "w+" do |out|
              out.puts template.result binding
            end
          end
        end

      end
    end
  end
end
