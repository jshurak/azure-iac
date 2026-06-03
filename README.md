# azure-iac

Infrastructure-as-code for an Azure landing zone, built with [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview). Templates use `@description` and `metadata` decorators so parameter help appears in the IDE, deployment UI, and generated ARM JSON.

## Overview

[`azure-iac-0/main.bicep`](azure-iac-0/main.bicep) deploys at **subscription** scope and composes the core landing zone. Shared Bicep modules live in [`modules/`](modules/) at the repository root so multiple deployment stacks can reuse the same building blocks.

| Resource / module | Description |
|-------------------|-------------|
| `{namePrefix}-core-rg` | Core resource group for shared infrastructure. |
| `modules/hubnetwork.bicep` | Hub VNet (`{namePrefix}-hub-vnet`) with Firewall, Gateway, Bastion, and Private Link subnets. |
| `modules/keyvault.bicep` | Key Vault with RBAC and template-deployment access (AVM). |
| `modules/storage.bicep` | StorageV2 account with public blob access disabled (AVM). |

Default environment values live in [`azure-iac-0/main.bicepparam`](azure-iac-0/main.bicepparam).

### Hub network layout

Subnets are carved from the VNet CIDR with `cidrSubnet()` (default space `10.0.0.0/16`):

| Subnet | Default prefix length |
|--------|------------------------|
| Firewall | /26 |
| Gateway | /26 |
| Bastion | /26 |
| PrivateLink | /24 |

`hubnetwork.bicep` exposes `subnetIDs` and `subnetNames` outputs for downstream stacks (for example, private endpoints).

Registry modules: [AVM virtual network](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/virtual-network), [AVM Key Vault](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/key-vault/vault), [AVM storage account](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/storage/storage-account).

## Repository structure

```
.
├── modules/                         # Shared modules (referenced by deployment stacks)
│   ├── hubnetwork.bicep             # Hub VNet and subnets
│   ├── keyvault.bicep               # Key Vault
│   └── storage.bicep               # Storage account
├── azure-iac-0/                     # Core landing-zone deployment
│   ├── main.bicep                   # Subscription entry: RG + hub network, Key Vault, storage
│   └── main.bicepparam              # Default parameter values for main.bicep
└── .github/workflows/
    ├── iac-0-unit-test.yml          # PR: lint, validate, what-if, Checkov
    └── iac-0-lint-validate-deploy.yml  # main: lint, validate, deploy (azure-iac-0 paths)
```

Workload-specific templates can keep their own `modules/` folder or reference shared modules with a relative path (for example, `../modules/hubnetwork.bicep` from a sibling stack directory).

## Documentation in templates

Each `.bicep` file documents its contract with Bicep decorators:

- **`metadata description`** — short summary of the file (shown in template metadata).
- **`@description`** — on parameters, variables, resources, and modules (tooltips in VS Code and parameter files in the portal).

Parameter tables below mirror those decorators. To view them locally, open any `.bicep` file and hover a parameter name, or run:

```bash
az bicep build --file azure-iac-0/main.bicep
# Inspect parameters[].metadata.description in the generated JSON
```

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) with Bicep (`az bicep install` if needed)
- Azure subscription with rights to deploy at subscription scope and create resource groups
- For CI/CD: GitHub OIDC federation for `azure/login@v2`

## Parameters

### `azure-iac-0/main.bicep`

| Parameter | Default (`main.bicepparam`) | Description |
|-----------|----------------------------|-------------|
| `location` | `eastus2` | Azure region for the core resource group and deployed modules. |
| `namePrefix` | `js` | Prefix applied to resource names (for example, `js-core-rg`, `js-hub-vnet`). |
| `storageSku` | `Standard_LRS` | Replication SKU for the core storage account (`Standard_LRS` or `Standard_ZRS`). |
| `ipAddressSpace` | `10.0.0.0` | Base IPv4 address for the hub VNet, without the CIDR suffix. |
| `CIDR` | `/16` | CIDR suffix for the hub VNet, including the leading slash. |

### `modules/hubnetwork.bicep`

| Parameter | Default | Description |
|-----------|---------|-------------|
| `location` | (required) | Azure region for the hub virtual network. |
| `namePrefix` | (required) | Prefix used in resource names (for example, `js-hub-vnet`). |
| `ipAddressSpace` | (required) | Base IPv4 address for the virtual network (without suffix). |
| `CIDR` | (required) | CIDR suffix for the VNet, including leading slash (for example, `/16`). |
| `subnets` | Firewall, Gateway, Bastion `/26`; PrivateLink `/24` | Subnet names and prefix lengths passed to `cidrSubnet()`. |

### `modules/keyvault.bicep`

| Parameter | Default | Description |
|-----------|---------|-------------|
| `namePrefix` | (required) | Prefix used in the Key Vault name. |
| `location` | Resource group location | Azure region for the Key Vault. |

### `modules/storage.bicep`

| Parameter | Default | Description |
|-----------|---------|-------------|
| `namePrefix` | (required) | Prefix used in the storage account name. |
| `storageSku` | (required) | Azure Storage replication SKU (`Standard_LRS` or `Standard_ZRS`). |

## Local development

Log in and set your subscription:

```bash
az login
az account set --subscription "<subscription-id>"
```

Compile templates:

```bash
az bicep build --file azure-iac-0/main.bicep
az bicep build --file modules/hubnetwork.bicep
az bicep build --file modules/keyvault.bicep
az bicep build --file modules/storage.bicep
```

Deploy with parameter file:

```bash
az deployment sub create \
  --location eastus2 \
  --template-file azure-iac-0/main.bicep \
  --parameters azure-iac-0/main.bicepparam
```

Override a single parameter:

```bash
az deployment sub create \
  --location eastus2 \
  --template-file azure-iac-0/main.bicep \
  --parameters azure-iac-0/main.bicepparam namePrefix=dev
```

Preview changes:

```bash
az deployment sub what-if \
  --location eastus2 \
  --template-file azure-iac-0/main.bicep \
  --parameters azure-iac-0/main.bicepparam
```

## CI/CD

### Pull requests (`iac-0-unit-test.yml`)

On PRs to `main`:

1. **Lint** — `az bicep build` on `azure-iac-0/main.bicep`
2. **Validate** — OIDC login, subscription-scoped deployment validate and what-if
3. **Security** — [Checkov](https://www.checkov.io/) for Bicep (SARIF to GitHub Security)

### `main` branch (`iac-0-lint-validate-deploy.yml`)

On push to `main` under `azure-iac-0/**`: lint, validate, then **deploy** (GitHub `production` environment).

### Required GitHub secrets

| Secret | Used for |
|--------|----------|
| `AZURE_CLIENT_ID` | OIDC application client ID |
| `AZURE_TENANT_ID` | Microsoft Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription |
| `AZURE_RESOURCE_GROUP_NAME` | Resource group for validate / deploy workflows |
| `AZURE_KEYVAULT_RESOURCEGROUP_NAME` | Key Vault resource group (workflow parameters) |
| `AZURE_KEYVAULT_NAME` | Key Vault name (workflow parameters) |

Workflows reference `azure-iac-0/main.bicepparam` and may pass additional inline parameters. Keep workflow parameter names aligned with `azure-iac-0/main.bicep` as the template evolves.

Configure [federated credentials](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-create-trust) on the app registration for passwordless GitHub Actions login.

## License

Add a license file if you plan to share or open-source this repository.
