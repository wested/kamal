class Kamal::Secrets::Adapters::Credstash < Kamal::Secrets::Adapters::Base
  # This adapter uses the credstash CLI to fetch secrets from AWS DynamoDB and S3.
  # Requires credstash CLI to be installed and configured with AWS credentials
  # via ~/.aws/credentials or environment variables.

  def requires_account?
    false
  end

  private
    def login(account = nil)
      raise RuntimeError, "Credstash CLI is not installed" unless cli_installed?

      return if loggedin?
      raise RuntimeError, "Could not access Credstash (check AWS credentials)" unless $?.success?
    end

    def loggedin?
      `credstash list 2> /dev/null`
      $?.success?
    end

    def fetch_secrets(secrets, from:, account: nil, session: nil)
      raise ArgumentError, "secrets should be an array" unless secrets.is_a?(Array)

      json_output = `credstash get #{from.shellescape}`.tap do
        raise RuntimeError, "Could not read secrets from credstash namespace '#{from}'" unless $?.success?
      end

      begin
        all_secrets = JSON.parse(json_output)
      rescue JSON::ParserError
        raise RuntimeError, "Invalid JSON response from credstash for namespace '#{from}'"
      end

      {}.tap do |results|
        secrets.each do |secret|
          if all_secrets.key?(secret)
            results[secret] = all_secrets[secret]
          else
            raise RuntimeError, "Secret '#{secret}' not found in credstash namespace '#{from}'"
          end
        end

        missing = secrets - results.keys
        raise RuntimeError, "Could not find the following secrets: #{missing.join(", ")}" unless missing.empty?
      end
    end

    def check_dependencies!
      raise RuntimeError, "Credstash CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `credstash -h 2> /dev/null`
      $?.success?
    end
end
