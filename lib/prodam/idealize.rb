# encoding: utf-8

ENV['NLS_LANG'] = 'AMERICAN_AMERICA.UTF8'
ENV['NLS_SORT'] = 'BINARY_AI'
ENV['NLS_COMP'] = 'LINGUISTIC'
DEFAULT_OCI8_ENCODING = 'utf-8'

require 'date'
require 'pathname'
require 'yaml'
require 'sequel'
require 'json'
require 'prodam/idealize/version'

class String
  def camelcase
    gsub('/', ' :: ').split(/[ _]/).map(&:capitalize).join
  end

  def underscore
    gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end

module Sequel
  module Plugins
    module Paging
      module DatasetMethods
        @paging = nil

        def paging(options = nil)
          @paging || (paging! options)
        end

        def page(number = 1)
          paging[:page] = number > 0 ? number : 1
          paging[:current] = paging[:page] > paging[:total] ? paging[:total] : paging[:page]
          paging[:offset] = ((paging[:current] - 1).abs * paging[:limit])
          paging[:next] = paging[:current] < paging[:total] ? paging[:current] + 1 : paging[:total]
          paging[:previous] = paging[:current] <= paging[:next] ? paging[:current] - 1 : 1
          limit(paging[:limit]).offset(paging[:offset])
        end

        def paging!(options = nil)
          @paging = { limit: 7 }
          options && @paging.update(options)
          @paging[:total] = ((count.to_i) / @paging[:limit].to_f).ceil
          @paging
        end
      end # ClassMethods
    end # Paging
  end # Plugins
end # Sequel

module Prodam
  module Idealize
    class << self
      def root_directory
        @root_directory ||= Pathname.new(File.expand_path("#{File.basename(__FILE__)}/.."))
      end

      def environment
        (ENV['RACK_ENV'].nil? ? :development : ENV['RACK_ENV']).to_sym
      end

      def load_config(file)
        load_yaml(:config, file)
      end

      def load_data(file)
        load_yaml(:db, file)
      end

      def application_config
        @application_config ||= load_config(:application)
      end

      def database_config
        @database_config ||= load_config(:database)
      end

      def routing(routing = controllers)
        @routes ||= routing.each_with_object({}) do |(id, controller), routers|
          controller[:routes] && routers.merge(routing(controller[:routes]))
          routers[controller[:url_path]] = const_get controller[:const_name]
          routers
        end
        @routes
      end

      def controllers(routers = application_config[:routes])
        @controllers ||= routers.each_with_object({}) do |(path, data), controllers|
          id = path.split('/').reject(&:empty?)
          id = id.any? && id.join('_').to_sym || :home
          data[:require_path] = format('%s/%s', :controllers, data[:controller].underscore)
          data[:url_path] = path
          data[:const_name] = data[:controller].to_sym
          controllers[id] = data
        end
        @controllers
      end

      def pages(pages = application_config[:pages])
        @pages ||= pages.each_with_object({}) do |(path, data), pages|
          id = path.gsub('/','').underscore.to_sym
          data[:url_path] = path
          pages[id] = data
        end
        @pages
      end

      def sections
        @sections || (@sections = controllers.merge(pages))
      end

      def sources_from(*pathnames)
        pathnames.each_with_object({}) do |pathname, sources|
          Dir[root_directory.join('app').join(pathname.to_s).join('*.rb')].each do |source|
            id = File.basename(source.gsub(/.*\/#{pathname}/, ''), '.rb')
            sources[id.to_sym] = {
              require_path: "#{pathname}/#{id}",
              const_name: id.camelcase.to_sym
            }
          end
        end
      end

    private

      def load_yaml(prefix, file)
        YAML.load_file(root_directory.join(prefix.to_s, "#{file}.yml"))
      end
    end

  class Database
    # Sequel::Inflections.clear

    Sequel.inflections do |inflect|
      inflect.irregular 'coautor', 'coautores'
      inflect.irregular 'apoiador', 'apoiadores'
      inflect.irregular 'modificacao', 'modificacoes'
      inflect.irregular 'situacao', 'situacoes'
      inflect.irregular 'avaliacao', 'avaliacoes'
      inflect.irregular 'classificacao', 'classificacoes'
      inflect.irregular 'premiacao', 'premiacoes'
    end

    class << self
      attr_reader :options

      def connection(env = Idealize.environment)
        @options = Idealize.database_config[env.to_sym]
        @options[:prefetch_rows] = 50
        if @options[:debug]
          require 'logger'
          @options[:loggers] = [Logger.new($stdout)]
        end
        @connection ||= Sequel.connect @options
      end

      def [](dataset)
        connection[dataset]
      end
    end
  end # Database

  module Model
    def self.[](dataset_name)
      klass = Sequel::Model(Database[dataset_name])
      klass.dataset = klass.dataset.sequence("s_#{dataset_name}".to_sym)
      klass.include InstanceMethods
      klass
    end

    module InstanceMethods
      def self.included(base)
        base.extend ClassMethods
      end

      def param_name
        id || ''
      end

      def to_url_param(prefix = nil)
        [prefix, param_name_clean].compact.join('/')
      end

    protected

      def param_name_clean
        param_name.gsub(/\W/, '-').sub(/-$/,'').squeeze('-')
      end
    end

    module ClassMethods
      def column_aliases
        columns.map do |column|
          "#{table_name}__#{column}".to_sym
        end
      end
    end
  end # Model

  # Controllers
  autoload :ApplicationController, 'controllers/application_controller'

  def self.autoload_sources
    sources_from(:models, :services, :helpers, :controllers).each do |id, source|
      autoload source[:const_name], source[:require_path]
    end
  end

  autoload_sources
end

end # Prodam::idealize
