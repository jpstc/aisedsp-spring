#!/bin/bash

# Azure CLI Verification Script for AISEDSP-Spring
# Verifies all deployed resources and their status
# Usage: bash infra/scripts/verify-azure-cli.sh [resource-group-name] [subscription-id]

set -e

# Configuration
RG=${1:-"aisedsp-spring-rg"}
SUBSCRIPTION=${2:-""}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED++))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

print_info() {
    echo "   $1"
}

# Main verification script
main() {
    print_header "AISEDSP-SPRING Azure Deployment Verification"
    
    # 1. Check Azure CLI installation
    print_section "1. Checking Azure CLI installation"
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not installed"
        echo "   Install from: https://learn.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    print_success "Azure CLI is installed"
    
    # 2. Check Azure login
    print_section "2. Checking Azure login status"
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure"
        echo "   Run: az login"
        exit 1
    fi
    
    CURRENT_ACCOUNT=$(az account show --query "user.name" -o tsv)
    print_success "Logged in as: $CURRENT_ACCOUNT"
    
    if [ -n "$SUBSCRIPTION" ]; then
        az account set --subscription "$SUBSCRIPTION"
        print_info "Set subscription to: $SUBSCRIPTION"
    fi
    
    CURRENT_SUB=$(az account show --query "id" -o tsv)
    print_info "Current subscription: $CURRENT_SUB"
    
    # 3. Check resource group exists
    print_section "3. Verifying resource group"
    if ! az group exists -n "$RG" | grep -q true; then
        print_error "Resource group '$RG' does not exist"
        exit 1
    fi
    print_success "Resource group '$RG' exists"
    
    RG_LOCATION=$(az group show -n "$RG" --query "location" -o tsv)
    print_info "Location: $RG_LOCATION"
    
    # 4. Check all required resources
    print_section "4. Verifying deployed resources"
    verify_resources
    
    # 5. Check Key Vault and secrets
    print_section "5. Verifying Key Vault and secrets"
    verify_key_vault
    
    # 6. Check SQL Server and Database
    print_section "6. Verifying SQL Server and Database"
    verify_sql
    
    # 7. Check Service Bus
    print_section "7. Verifying Service Bus"
    verify_servicebus
    
    # 8. Check Container Apps
    print_section "8. Verifying Container Apps"
    verify_container_apps
    
    # 9. Check API Management
    print_section "9. Verifying API Management"
    verify_apim
    
    # 10. Check Log Analytics
    print_section "10. Verifying Log Analytics Workspace"
    verify_log_analytics
    
    # Summary
    print_header "Verification Summary"
    echo -e "Total checks passed:  ${GREEN}$PASSED${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "Total warnings:       ${YELLOW}$WARNINGS${NC}"
    fi
    if [ $FAILED -gt 0 ]; then
        echo -e "Total checks failed:  ${RED}$FAILED${NC}"
    fi
    echo ""
    
    if [ $FAILED -gt 0 ]; then
        echo -e "${RED}Some verification checks failed!${NC}"
        echo "Please review the errors above and consult VERIFICATION_GUIDE.md"
        return 1
    else
        echo -e "${GREEN}All verification checks passed!${NC}"
        if [ $WARNINGS -gt 0 ]; then
            echo -e "${YELLOW}Note: Some warnings were detected. Review them above.${NC}"
        fi
        return 0
    fi
}

verify_resources() {
    echo "   Checking for required resources..."
    
    local resources=(
        "keyVaults:Key Vault"
        "servers:SQL Server"
        "namespaces:Service Bus"
        "workspaces:Log Analytics"
        "managedEnvironments:Container Apps Environment"
    )
    
    for resource in "${resources[@]}"; do
        IFS=: read -r resource_type display_name <<< "$resource"
        count=$(az resource list -g "$RG" --resource-type "Microsoft.${resource_type%%/*}/${resource_type#*/}" --query "length" 2>/dev/null || echo 0)
        
        if [ "$count" -gt 0 ]; then
            print_success "$display_name found ($count)"
        else
            print_error "$display_name not found"
        fi
    done
}

verify_key_vault() {
    KV=$(az keyvault list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -z "$KV" ]; then
        print_error "Key Vault not found"
        return 1
    fi
    
    print_success "Key Vault found: $KV"
    
    # Check if user has access
    if ! az keyvault secret list --vault-name "$KV" &> /dev/null; then
        print_warning "Cannot access Key Vault secrets (possible RBAC issue)"
        print_info "See KEYVAULT_RBAC_FIX.md for resolution"
        return
    fi
    
    # List secrets
    local secrets=($(az keyvault secret list --vault-name "$KV" --query "[].name" -o tsv 2>/dev/null))
    
    if [ ${#secrets[@]} -eq 0 ]; then
        print_warning "No secrets found in Key Vault"
        print_info "Required secrets: sql-connection-string, servicebus-connection-string"
    else
        print_success "Found ${#secrets[@]} secret(s):"
        for secret in "${secrets[@]}"; do
            print_info "- $secret"
        done
    fi
}

verify_sql() {
    SQL_SERVER=$(az sql server list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -z "$SQL_SERVER" ]; then
        print_error "SQL Server not found"
        return 1
    fi
    
    print_success "SQL Server found: $SQL_SERVER"
    print_info "FQDN: ${SQL_SERVER}.database.windows.net"
    
    # Check databases
    local databases=($(az sql db list -g "$RG" -s "$SQL_SERVER" --query "[].name" -o tsv 2>/dev/null))
    
    if [ ${#databases[@]} -eq 0 ]; then
        print_error "No databases found"
        return 1
    fi
    
    print_success "Found ${#databases[@]} database(s):"
    
    for db in "${databases[@]}"; do
        local status=$(az sql db show -g "$RG" -s "$SQL_SERVER" -n "$db" --query "status" -o tsv 2>/dev/null)
        
        case "$status" in
            "Online")
                print_success "Database '$db': $status"
                ;;
            "Paused")
                print_warning "Database '$db': $status (normal, resumes on first access)"
                ;;
            *)
                print_error "Database '$db': $status (unexpected)"
                ;;
        esac
    done
    
    # Check firewall rules
    check_sql_firewall "$SQL_SERVER"
}

check_sql_firewall() {
    local sql_server=$1
    echo "   Checking firewall rules..."
    
    # Check if "Allow Azure services" is enabled
    local allow_azure=$(az sql server firewall-rule show -g "$RG" -s "$sql_server" -n "AllowAllAzureIps" --query "name" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$allow_azure" ]; then
        print_success "Azure services firewall rule enabled"
    else
        print_warning "Azure services firewall rule may not be properly configured"
    fi
}

verify_servicebus() {
    SB=$(az servicebus namespace list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -z "$SB" ]; then
        print_error "Service Bus not found"
        return 1
    fi
    
    print_success "Service Bus found: $SB"
    
    # Check namespace status
    local status=$(az servicebus namespace show -g "$RG" -n "$SB" --query "status" -o tsv 2>/dev/null)
    
    if [ "$status" = "Active" ]; then
        print_success "Namespace status: $status"
    else
        print_warning "Namespace status: $status"
    fi
    
    # List queues/topics
    local queues=$(az servicebus queue list -g "$RG" --namespace-name "$SB" --query "length" -o tsv 2>/dev/null || echo 0)
    if [ "$queues" -gt 0 ]; then
        print_success "Found $queues queue(s)"
    fi
    
    local topics=$(az servicebus topic list -g "$RG" --namespace-name "$SB" --query "length" -o tsv 2>/dev/null || echo 0)
    if [ "$topics" -gt 0 ]; then
        print_success "Found $topics topic(s)"
    fi
}

verify_container_apps() {
    # Check Container Apps Environment
    local env=$(az containerapp env list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -z "$env" ]; then
        print_error "Container Apps Environment not found"
        return 1
    fi
    
    print_success "Container Apps Environment found: $env"
    
    # Check individual apps
    local apps=($(az containerapp list -g "$RG" --query "[].name" -o tsv 2>/dev/null))
    
    if [ ${#apps[@]} -eq 0 ]; then
        print_error "No Container Apps found"
        return 1
    fi
    
    print_success "Found ${#apps[@]} Container App(s)"
    
    for app in "${apps[@]}"; do
        local provision_state=$(az containerapp show -g "$RG" -n "$app" --query "properties.provisioningState" -o tsv 2>/dev/null)
        local state=$(az containerapp show -g "$RG" -n "$app" --query "properties.runningState" -o tsv 2>/dev/null)
        
        case "$state" in
            "Running")
                print_success "App '$app': $state"
                ;;
            "Stopped")
                print_warning "App '$app': $state (not running)"
                ;;
            *)
                print_info "App '$app': $state (provisioning state: $provision_state)"
                ;;
        esac
        
        # Try to get FQDN
        local fqdn=$(az containerapp show -g "$RG" -n "$app" --query "properties.configuration.ingress.fqdn" -o tsv 2>/dev/null)
        if [ -n "$fqdn" ] && [ "$fqdn" != "null" ]; then
            print_info "  URL: https://$fqdn"
        fi
    done
}

verify_apim() {
    APIM=$(az apim list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -z "$APIM" ]; then
        print_warning "API Management not found (optional)"
        return 0
    fi
    
    print_success "API Management found: $APIM"
    
    local apim_state=$(az apim show -g "$RG" -n "$APIM" --query "properties.provisioningState" -o tsv 2>/dev/null)
    if [ "$apim_state" = "Succeeded" ]; then
        print_success "APIM provisioning state: $apim_state"
    else
        print_warning "APIM provisioning state: $apim_state"
    fi
    
    local gateway_url="https://${APIM}.azure-api.net"
    print_info "Gateway URL: $gateway_url"
}

verify_log_analytics() {
    LOG_WORKSPACE=$(az monitor log-analytics workspace list -g "$RG" --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -z "$LOG_WORKSPACE" ]; then
        print_warning "Log Analytics Workspace not found (optional)"
        return 0
    fi
    
    print_success "Log Analytics Workspace found: $LOG_WORKSPACE"
    
    local workspace_id=$(az monitor log-analytics workspace show -g "$RG" -n "$LOG_WORKSPACE" --query "customerId" -o tsv 2>/dev/null)
    print_info "Workspace ID: $workspace_id"
}

# Run main function
main "$@"
exit $?
