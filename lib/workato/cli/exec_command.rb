# frozen_string_literal: true

require 'thor'
require 'ruby-progressbar'

module Workato
  module CLI
    class ExecCommand
      include Thor::Shell

      def initialize(path:, options:)
        @path = path
        @options = options
      end

      def call
        load_from_default_files
        inspect_params(params)
        output = with_progress { execute_path }
        show_output(output)
        output
      end

      private

      attr_reader :path,
                  :options

      # rubocop:disable Style/GuardClause
      def load_from_default_files
        if File.exist?(Workato::Connector::Sdk::DEFAULT_SCHEMAS_PATH)
          Workato::Connector::Sdk::WorkatoSchemas.from_json
        end
        if File.exist?(Workato::Connector::Sdk::DEFAULT_LOOKUP_TABLES_PATH)
          Workato::Connector::Sdk::LookupTables.from_yaml
        end
        if File.exist?(Workato::Connector::Sdk::DEFAULT_ACCOUNT_PROPERTIES_PATH)
          Workato::Connector::Sdk::AccountProperties.from_yaml
        end
        if File.exist?(Workato::Connector::Sdk::DEFAULT_ENCRYPTED_ACCOUNT_PROPERTIES_PATH)
          Workato::Connector::Sdk::AccountProperties.from_encrypted_yaml
        end
      end
      # rubocop:enable Style/GuardClause

      def params
        @params ||= {
          connector: connector,
          settings: settings,
          input: from_json(options[:input]),
          output: from_json(options[:input]),
          webhook_subscribe_output: from_json(options[:input]),
          args: from_json(options[:args]).presence || [],
          extended_input_schema: from_json(options[:extended_input_schema]).presence || [],
          extended_output_schema: from_json(options[:extended_output_schema]).presence || [],
          config_fields: from_json(options[:config_fields]),
          closure: from_json(options[:closure], parse_json_times: true).presence,
          payload: from_json(options[:webhook_payload]),
          params: from_json(options[:webhook_params]),
          headers: from_json(options[:webhook_headers]),
          webhook_url: options[:webhook_url],
          recipe_id: SecureRandom.uuid
        }
      end

      def connector
        Workato::Connector::Sdk::Connector.from_file(
          options[:connector] || Workato::Connector::Sdk::DEFAULT_CONNECTOR_PATH,
          settings
        )
      end

      def settings
        return @settings if defined?(@settings)

        settings_store = Workato::Connector::Sdk::Settings.new(
          path: options[:settings],
          name: options[:connection],
          key_path: options[:key]
        )
        @settings = settings_store.read

        Workato::Connector::Sdk::Operation.on_settings_updated = lambda do |_, _, exception, new_settings|
          $stdout.pause if verbose?
          say('')
          say("Refresh token triggered on response \"#{exception}\"")
          loop do
            answer = ask('Updated settings file with new connection attributes? (Yes or No)').to_s.downcase
            break if %w[n no].include?(answer)
            break settings_store.update(new_settings) if %w[y yes].include?(answer)
          end
          $stdout.resume if verbose?
        end

        @settings
      end

      def from_json(path, parse_json_times: false)
        old_parse_json_times = ActiveSupport.parse_json_times
        ::ActiveSupport.parse_json_times = parse_json_times
        result = path ? ::ActiveSupport::JSON.decode(File.read(path)) : {}
        ::ActiveSupport.parse_json_times = old_parse_json_times
        result
      end

      def inspect_params(params)
        return unless verbose?

        if params[:settings].present?
          say('SETTINGS')
          jj params[:settings]
        end

        say('INPUT')
        jj params[:input]
      end

      def execute_path
        methods = path.split('.')
        method = methods.pop
        object = methods.inject(params[:connector]) { |obj, m| obj.public_send(m) }
        parameters = object.method(method).parameters.reject { |p| p[0] == :block }.map(&:second)
        args = params.values_at(*parameters)
        if parameters.last == :args
          args = args.take(args.length - 1) + Array.wrap(args.last).flatten(1)
        end
        object.public_send(method, *args)
      rescue Exception => e # rubocop:disable Lint/RescueException
        raise e if options[:debug]

        e.message
      end

      def show_output(output)
        if options[:output].present?
          File.open(options[:output], 'w') do |f|
            f.write(JSON.dump(output))
          end
        elsif options[:output].nil?
          say('OUTPUT') if verbose?
          jj output
        end
      end

      def verbose?
        !!options[:verbose]
      end

      def with_progress
        return yield unless verbose?

        say('')

        old_stdout = $stdout
        progress_bar = ProgressBar.create(total: nil, output: old_stdout)
        $stdout = ProgressLogger.new(progress_bar)
        RestClient.log = $stdout

        dots = Thread.start do
          loop do
            progress_bar.increment unless progress_bar.paused?
            sleep(0.2)
          end
        end
        output = yield
        dots.kill
        progress_bar.finish

        $stdout = old_stdout

        say('')

        output
      end

      class ProgressLogger < SimpleDelegator
        def initialize(progress)
          super($stdout)
          @progress = progress
        end

        delegate :log, :pause, :resume, to: :@progress

        alias << log
        alias write log
        alias puts log
        alias print log
      end
    end
  end
end