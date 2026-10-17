#!/usr/bin/env ruby
# frozen_string_literal: true

# teardown-oidc.rb — undo scripts/setup-oidc.rb.
#
# Removes the HCP Terraform dynamic-credentials wiring for Azure:
#   1. Azure : delete the app registration, its service principal, and the
#              service principal's role assignments.
#   2. HCP   : delete the workspace environment variables that turned on
#              dynamic credentials.
#
# Requires the `az` CLI (logged in) and an HCP token (env TF_TOKEN_app_terraform_io
# or ~/.terraform.d/credentials.tfrc.json).
#
# Usage:
#   scripts/teardown-oidc.rb \
#     --org akshay2642005 --workspace zero-trust-azure-dev \
#     [--app-name hcp-terraform-zero-trust] [--dry-run] [--yes]

require "json"
require "net/http"
require "open3"
require "optparse"
require "uri"

HCP_API = "https://app.terraform.io/api/v2"
# Exactly the variables setup-oidc.rb creates.
OIDC_VARS = %w[
  TFC_AZURE_PROVIDER_AUTH
  TFC_AZURE_RUN_CLIENT_ID
  ARM_TENANT_ID
  ARM_SUBSCRIPTION_ID
].freeze

class TeardownError < StandardError; end

class OidcTeardown
  def initialize(opts)
    @opts = opts
    @dry_run = opts[:dry_run]
  end

  def run
    preflight!
    confirm! unless @dry_run

    remove_azure
    remove_hcp_variables

    puts "\nDone. Dynamic credentials torn down for #{@opts[:org]}/#{@opts[:workspace]}."
  end

  private

  # --- Azure ---------------------------------------------------------------

  def az(*args, mutate: false)
    if @dry_run && mutate
      puts "  [dry-run] az #{args.join(' ')}"
      return ""
    end
    out, err, status = Open3.capture3("az", *args)
    raise TeardownError, "az #{args.join(' ')} failed:\n#{err.strip}" unless status.success?

    out.strip
  end

  def az_json(*args, mutate: false)
    raw = az(*args, "-o", "json", mutate: mutate)
    raw.nil? || raw.empty? ? [] : JSON.parse(raw)
  end

  def remove_azure
    if @dry_run
      puts "  [dry-run] would delete app registration #{@opts[:app_name].inspect} (if present)"
      puts "  [dry-run] would delete its service principal and role assignments"
      return
    end

    app = find_app
    return puts("No app registration named #{@opts[:app_name].inspect} — nothing to remove in Azure.") unless app

    app_id = app["appId"]
    puts "App registration: #{@opts[:app_name]} (#{app_id})"

    sp = find_service_principal(app_id)
    if sp
      object_id = sp["id"]
      delete_role_assignments(object_id)
      az("ad", "sp", "delete", "--id", object_id, mutate: true)
      puts "  deleted service principal"
    else
      puts "  no service principal found"
    end

    az("ad", "app", "delete", "--id", app_id, mutate: true)
    puts "  deleted app registration"
  end

  def find_app
    return nil if @dry_run

    apps = az_json("ad", "app", "list", "--display-name", @opts[:app_name])
    apps.find { |a| a["displayName"] == @opts[:app_name] }
  end

  def find_service_principal(app_id)
    return nil if @dry_run

    sps = az_json("ad", "sp", "list", "--filter", "appId eq '#{app_id}'", "--all")
    sps.first
  end

  def delete_role_assignments(object_id)
    assignments = az_json("role", "assignment", "list", "--assignee", object_id, "--all") || []
    if assignments.empty?
      puts "  no role assignments"
      return
    end
    assignments.each do |a|
      scope = a["scope"]
      role = a["roleDefinitionName"]
      puts "  removing role #{role} at #{scope}"
      az("role", "assignment", "delete", "--assignee", object_id, "--role", role,
         "--scope", scope, mutate: true)
    end
  end

  # --- HCP -----------------------------------------------------------------

  def remove_hcp_variables
    ws_id = workspace_id
    index = variable_index(ws_id)
    present = OIDC_VARS & index.keys

    if present.empty?
      puts "No OIDC workspace variables to remove."
      return
    end

    present.each do |key|
      puts "  delete var #{key}"
      hcp(:delete, "workspaces/#{ws_id}/vars/#{index[key]}")
    end
  end

  def workspace_id
    return "<WORKSPACE_ID>" if @dry_run

    data = hcp(:get, "organizations/#{@opts[:org]}/workspaces/#{@opts[:workspace]}")
    data.dig("data", "id") or raise TeardownError, "workspace #{@opts[:workspace]} not found"
  end

  def variable_index(ws_id)
    return OIDC_VARS.to_h { |k| [k, "<VAR_ID>"] } if @dry_run

    data = hcp(:get, "workspaces/#{ws_id}/vars")
    data["data"].each_with_object({}) do |v, acc|
      acc[v.dig("attributes", "key")] = v["id"]
    end
  end

  def hcp(method, path, body = nil)
    if @dry_run && method != :get
      puts "  [dry-run] #{method.to_s.upcase} #{path}"
      return nil
    end

    uri = URI("#{HCP_API}/#{path}")
    request =
      case method
      when :get    then Net::HTTP::Get.new(uri)
      when :delete then Net::HTTP::Delete.new(uri)
      else raise TeardownError, "unsupported method #{method}"
      end

    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"]  = "application/vnd.api+json"
    request.body = JSON.generate(body) if body

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    unless response.is_a?(Net::HTTPSuccess)
      raise TeardownError, "HCP #{method.to_s.upcase} #{path} -> #{response.code}: #{response.body}"
    end

    response.body.to_s.empty? ? {} : JSON.parse(response.body)
  end

  # --- misc ----------------------------------------------------------------

  def preflight!
    unless @dry_run
      system("az", "--version", out: File::NULL, err: File::NULL) ||
        raise(TeardownError, "missing required executable: az (install the Azure CLI and run `az login`)")
    end
  end

  def confirm!
    puts "This will DELETE the app registration #{@opts[:app_name].inspect} and the OIDC"
    puts "workspace variables in #{@opts[:org]}/#{@opts[:workspace]}."
    print "Type 'yes' to continue: "
    raise TeardownError, "aborted" unless $stdin.gets.to_s.strip == "yes"
  end

  def token
    @token ||= load_token
  end

  def load_token
    env = ENV["TF_TOKEN_app_terraform_io"]
    return env if env && !env.empty?

    path = File.expand_path("~/.terraform.d/credentials.tfrc.json")
    raise TeardownError, "no HCP token: set TF_TOKEN_app_terraform_io or create #{path}" unless File.exist?(path)

    parsed = JSON.parse(File.read(path)).dig("credentials", "app.terraform.io", "token")
    raise TeardownError, "no app.terraform.io token in #{path}" unless parsed

    parsed
  end
end

options = {
  org: "akshay2642005",
  workspace: "zero-trust-azure-dev",
  app_name: "hcp-terraform-zero-trust",
  dry_run: false,
  yes: false,
}

OptionParser.new do |o|
  o.banner = "Usage: teardown-oidc.rb [options]"
  o.on("--org ORG", "HCP Terraform organization") { |v| options[:org] = v }
  o.on("--workspace NAME", "HCP Terraform workspace") { |v| options[:workspace] = v }
  o.on("--app-name NAME", "Azure app registration name") { |v| options[:app_name] = v }
  o.on("--dry-run", "Print actions without deleting anything") { options[:dry_run] = true }
  o.on("--yes", "Skip the confirmation prompt") { options[:yes] = true }
  o.on("-h", "--help", "Show this help") { puts o; exit }
end.parse!

begin
  OidcTeardown.new(options).run
rescue TeardownError => e
  warn "error: #{e.message}"
  exit 1
end
