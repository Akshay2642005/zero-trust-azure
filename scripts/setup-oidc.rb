#!/usr/bin/env ruby
# frozen_string_literal: true

# setup-oidc.rb — wire HCP Terraform dynamic credentials (OIDC) to Azure.
#
# Automates both halves of
# https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration
#
#   1. Azure : create an app registration + service principal, add one
#              federated identity credential per run phase (plan/apply), and
#              grant the principal a role.
#   2. HCP   : create/update the workspace environment variables that turn on
#              dynamic credentials, and remove any static-secret variables.
#
# Requires the `az` CLI (logged in) and an HCP token (env TF_TOKEN_app_terraform_io
# or ~/.terraform.d/credentials.tfrc.json).
#
# Usage:
#   scripts/setup-oidc.rb \
#     --org akshay2642005 \
#     --workspace zero-trust-azure-dev \
#     --subscription <sub-id> \
#     --tenant <tenant-id> \
#     [--project "Default Project"] [--app-name hcp-terraform-zero-trust] \
#     [--role Contributor] [--scope /subscriptions/<sub-id>] [--dry-run]

require "json"
require "net/http"
require "open3"
require "optparse"
require "uri"

HCP_API   = "https://app.terraform.io/api/v2"
ISSUER    = "https://app.terraform.io"
AUDIENCE  = "api://AzureADTokenExchange"
PHASES    = %w[plan apply].freeze
# Variables that would force static-secret auth and defeat dynamic credentials.
FORBIDDEN = %w[ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_USE_OIDC ARM_OIDC_TOKEN].freeze

class SetupError < StandardError; end

class OidcSetup
  def initialize(opts)
    @opts = opts
    @dry_run = opts[:dry_run]
  end

  def run
    preflight!
    client_id = ensure_app
    ensure_federated_credentials(client_id)
    ensure_role_assignment
    ensure_hcp_variables(client_id)
    summarise(client_id)
  end

  private

  # --- Azure helpers -------------------------------------------------------

  def az(*args, mutate: false)
    if @dry_run && mutate
      puts "  [dry-run] az #{args.join(' ')}"
      return "{}"
    end
    out, err, status = Open3.capture3("az", *args)
    raise SetupError, "az #{args.join(' ')} failed:\n#{err.strip}" unless status.success?

    out.strip
  end

  def az_json(*args, mutate: false)
    raw = az(*args, "-o", "json", mutate: mutate)
    raw.nil? || raw.empty? ? [] : JSON.parse(raw)
  end

  def ensure_app
    return "<CLIENT_ID>" if @dry_run

    existing = az_json("ad", "app", "list", "--display-name", @opts[:app_name])
    app = existing.find { |a| a["displayName"] == @opts[:app_name] }

    if app
      puts "App registration exists: #{app['displayName']} (#{app['appId']})"
    else
      app = az_json("ad", "app", "create", "--display-name", @opts[:app_name], mutate: true)
      puts "Created app registration: #{@opts[:app_name]} (#{app['appId']})"
    end

    client_id = app["appId"]

    sps = az_json("ad", "sp", "list", "--filter", "appId eq '#{client_id}'", "--all")
    if sps.empty?
      az("ad", "sp", "create", "--id", client_id, mutate: true)
      puts "Created service principal"
    else
      puts "Service principal exists"
    end
    # Re-read the object id (a freshly created SP is not in the list above).
    @sp_object_id = sps.dig(0, "id") ||
                    az("ad", "sp", "show", "--id", client_id, "--query", "id", "-o", "tsv")

    client_id
  end

  def ensure_federated_credentials(client_id)
    return if @dry_run

    existing = az_json("ad", "app", "federated-credential", "list", "--id", client_id)
    names = existing.map { |c| c["name"] }

    PHASES.each do |phase|
      name = "tfc-#{phase}"
      if names.include?(name)
        puts "Federated credential exists: #{name}"
        next
      end
      az("ad", "app", "federated-credential", "create", "--id", client_id,
         "--parameters", federated_params(name, phase), mutate: true)
      puts "Created federated credential: #{name}"
    end
  end

  def federated_params(name, phase)
    JSON.generate(
      name: name,
      issuer: ISSUER,
      subject: subject_for(phase),
      audiences: [AUDIENCE],
      description: "HCP Terraform dynamic credentials (#{phase})",
    )
  end

  def subject_for(phase)
    "organization:#{@opts[:org]}:project:#{project}:workspace:#{@opts[:workspace]}:run_phase:#{phase}"
  end

  def ensure_role_assignment
    scope = @opts[:scope] || "/subscriptions/#{@opts[:subscription]}"
    assignee = @sp_object_id || "SP_OBJECT_ID"

    if @dry_run
      puts "  [dry-run] would assign #{@opts[:role]} to the service principal at #{scope}"
      return
    end

    existing = az_json("role", "assignment", "list", "--assignee", assignee, "--scope", scope) || []
    if existing.any? { |a| a["roleDefinitionName"] == @opts[:role] }
      puts "Role assignment exists: #{@opts[:role]} at #{scope}"
      return
    end

    az("role", "assignment", "create", "--assignee", assignee, "--role", @opts[:role],
       "--scope", scope, mutate: true)
    puts "Assigned #{@opts[:role]} at #{scope}"
  end

  # --- HCP helpers ---------------------------------------------------------

  def ensure_hcp_variables(client_id)
    ws_id = workspace_id
    puts "HCP workspace id: #{ws_id}"

    index = variable_index(ws_id)

    desired = {
      "TFC_AZURE_PROVIDER_AUTH" => "true",
      "TFC_AZURE_RUN_CLIENT_ID" => client_id,
      "ARM_TENANT_ID"           => @opts[:tenant],
      "ARM_SUBSCRIPTION_ID"     => @opts[:subscription],
    }

    desired.each do |key, value|
      if (id = index[key])
        puts "  update var #{key}"
        hcp(:patch, "workspaces/#{ws_id}/vars/#{id}", var_payload(key, value))
      else
        puts "  create var #{key}"
        hcp(:post, "workspaces/#{ws_id}/vars", var_payload(key, value))
      end
    end

    (FORBIDDEN & index.keys).each do |key|
      puts "  delete stale var #{key}"
      hcp(:delete, "workspaces/#{ws_id}/vars/#{index[key]}")
    end
  end

  def workspace_id
    return "<WORKSPACE_ID>" if @dry_run

    data = hcp(:get, "organizations/#{@opts[:org]}/workspaces/#{@opts[:workspace]}")
    data.dig("data", "id") or raise SetupError, "workspace #{@opts[:workspace]} not found"
  end

  def variable_index(ws_id)
    return {} if @dry_run

    data = hcp(:get, "workspaces/#{ws_id}/vars")
    data["data"].each_with_object({}) do |v, acc|
      acc[v.dig("attributes", "key")] = v["id"]
    end
  end

  def var_payload(key, value)
    {
      data: {
        type: "vars",
        attributes: {
          key: key,
          value: value,
          category: "env",
          sensitive: false,
        },
      },
    }
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
      when :post   then Net::HTTP::Post.new(uri)
      when :patch  then Net::HTTP::Patch.new(uri)
      when :delete then Net::HTTP::Delete.new(uri)
      else raise SetupError, "unsupported method #{method}"
      end

    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"]  = "application/vnd.api+json"
    request.body = JSON.generate(body) if body

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    unless response.is_a?(Net::HTTPSuccess)
      raise SetupError, "HCP #{method.to_s.upcase} #{path} -> #{response.code}: #{response.body}"
    end

    response.body.to_s.empty? ? {} : JSON.parse(response.body)
  end

  def project
    @project ||=
      if @opts[:project]
        @opts[:project]
      elsif @dry_run
        "Default Project"
      else
        detect_project
      end
  end

  def detect_project
    data = hcp(:get, "organizations/#{@opts[:org]}/workspaces/#{@opts[:workspace]}?include=project")
    name = (data["included"] || []).find { |i| i["type"] == "projects" }&.dig("attributes", "name")
    puts "Detected workspace project: #{name.inspect}"
    name || "Default Project"
  end

  # --- misc ----------------------------------------------------------------

  def preflight!
    unless @dry_run
      system("az", "--version", out: File::NULL, err: File::NULL) ||
        raise(SetupError, "missing required executable: az (install the Azure CLI and run `az login`)")
    end
    raise SetupError, "--subscription is required" if @opts[:subscription].to_s.empty?
    raise SetupError, "--tenant is required" if @opts[:tenant].to_s.empty?
  end

  def token
    @token ||= load_token
  end

  def load_token
    env = ENV["TF_TOKEN_app_terraform_io"]
    return env if env && !env.empty?

    path = File.expand_path("~/.terraform.d/credentials.tfrc.json")
    raise SetupError, "no HCP token: set TF_TOKEN_app_terraform_io or create #{path}" unless File.exist?(path)

    parsed = JSON.parse(File.read(path)).dig("credentials", "app.terraform.io", "token")
    raise SetupError, "no app.terraform.io token in #{path}" unless parsed

    parsed
  end

  def summarise(client_id)
    puts <<~MSG

      Done. Dynamic credentials are wired for:
        org/workspace : #{@opts[:org]}/#{@opts[:workspace]}
        client id     : #{client_id}
        subjects      : organization:#{@opts[:org]}:project:#{project}:workspace:#{@opts[:workspace]}:run_phase:{plan,apply}

      Run `make plan` — the Azure CLI auth error should be gone.
      If Azure still rejects the token, the `project`/`workspace` in the subject
      must match exactly; re-run with --project to override.
    MSG
  end
end

options = {
  org: "akshay2642005",
  workspace: "zero-trust-azure-dev",
  app_name: "hcp-terraform-zero-trust",
  role: "Contributor",
  dry_run: false,
}

OptionParser.new do |o|
  o.banner = "Usage: setup-oidc.rb [options]"
  o.on("--org ORG", "HCP Terraform organization") { |v| options[:org] = v }
  o.on("--workspace NAME", "HCP Terraform workspace") { |v| options[:workspace] = v }
  o.on("--project NAME", "HCP project name (auto-detected if omitted)") { |v| options[:project] = v }
  o.on("--app-name NAME", "Azure app registration name") { |v| options[:app_name] = v }
  o.on("--subscription ID", "Azure subscription id") { |v| options[:subscription] = v }
  o.on("--tenant ID", "Azure tenant id") { |v| options[:tenant] = v }
  o.on("--role ROLE", "Azure role to assign") { |v| options[:role] = v }
  o.on("--scope SCOPE", "Azure scope (default /subscriptions/<id>)") { |v| options[:scope] = v }
  o.on("--dry-run", "Print actions without mutating anything") { options[:dry_run] = true }
  o.on("-h", "--help", "Show this help") { puts o; exit }
end.parse!

begin
  OidcSetup.new(options).run
rescue SetupError => e
  warn "error: #{e.message}"
  exit 1
end
