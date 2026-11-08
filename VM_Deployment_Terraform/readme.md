# Local VM Deployment with Terraform and Multipass

Terraform project for provisioning and configuring local virtual machines using [Multipass](https://canonical.com/multipass). It uses the [Todoroff Multipass Terraform provider](https://github.com/todoroff/terraform-provider-multipass) to manage VM lifecycle and cloud-init for initial system configuration.

The project is intended for **local VM deployments on a Linux host**, not cloud infrastructure provisioning.

## Prerequisites

### 1. Install Multipass

Install Multipass using Snap:

```bash
sudo snap install multipass
```

Verify:

```bash
multipass version
```

### 2. Install Terraform

Install Terraform using Snap:

```bash
sudo snap install terraform --classic
```

Verify:

```bash
terraform version
```

### 3. Install supporting tools

```bash
sudo apt update
sudo apt install -y qemu-utils openssh-client curl
```

- `qemu-utils`: inspect and manage QCOW2 images.
- `openssh-client`: generate and manage SSH keys.
- `curl`: download remote images.

### 4. Configure SSH access

Generate an SSH key if you don't already have one:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

The default Terraform configuration uses:

```text
~/.ssh/id_rsa.pub
```

The public key is injected into the VMs through cloud-init.

## Project Structure

```text
.
├── images/
│   └── resolute-server-cloudimg-amd64.img
├── scripts/
│   └── install-docker.sh
├── main.tf
└── README.md
```

- `main.tf`: Terraform configuration, VM definitions, cloud-init and outputs.
- `images/`: locally downloaded operating system images.
- `scripts/`: provisioning scripts executed inside VMs.
- `README.md`: project documentation.

## Configuration

VMs are defined in the `locals.vms` section of `main.tf`.

Each VM supports individual configuration:

- `image`: Multipass image alias, local image path or remote image URL.
- `cpus`: number of virtual CPUs.
- `memory`: allocated RAM.
- `disk`: virtual disk capacity.
- `packages`: packages installed through cloud-init.
- `commands`: commands executed during initial provisioning.

Example:

```hcl
tf-vm01 = {
  image  = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
  cpus   = 8
  memory = "4G"
  disk   = "20G"

  packages = [
    "curl",
    "ca-certificates",
    "ufw"
  ]

  commands = [
    "/bin/bash /usr/local/sbin/install-docker.sh",
    "ufw allow OpenSSH",
    "ufw --force enable",
  ]
}
```

### Custom OS Images

Multipass supports custom images in addition to its default image catalogue.

**Remote image:**

```hcl
image = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
```

**Local image:**

```hcl
image = "file:///var/snap/multipass/common/resolute-server-cloudimg-amd64.img"
```

For local images, place the image somewhere accessible to the Multipass daemon. With Snap installations, `/var/snap/multipass/common/` is a convenient location.

Images must be bootable disk images compatible with Multipass and include cloud-init. Installation ISO files are not equivalent to preinstalled cloud images.

## Deployment

### Initialize Terraform

Run from the project directory:

```bash
terraform init
```

This downloads the required Multipass provider.

### Validate configuration

```bash
terraform fmt
terraform validate
terraform plan
```

### Deploy VMs

```bash
terraform apply
```

Review the execution plan and enter `yes` to confirm.

Terraform creates the configured instances, applies cloud-init configuration and waits for cloud-init to complete.

## VM Management

### Terraform commands

| Command | Description |
|---|---|
| `terraform init` | Initialize the project and download providers |
| `terraform fmt` | Format Terraform configuration |
| `terraform validate` | Validate configuration |
| `terraform plan` | Preview infrastructure changes |
| `terraform apply` | Create or update VMs |
| `terraform output` | Display VM names and IP addresses |
| `terraform state list` | List Terraform-managed resources |
| `terraform destroy` | Destroy Terraform-managed VMs |

### Multipass commands

| Command | Description |
|---|---|
| `multipass list` | List instances |
| `multipass list --all` | List all instances, including stopped ones |
| `multipass info <name>` | Display VM information |
| `multipass shell <name>` | Open an interactive VM shell |
| `multipass exec <name> -- <command>` | Execute a command inside a VM |
| `multipass stop <name>` | Stop a VM |
| `multipass start <name>` | Start a stopped VM |
| `multipass restart <name>` | Restart a VM |
| `multipass delete <name>` | Mark a VM for deletion |
| `multipass delete --purge <name>` | Permanently delete a VM |

## Accessing VMs

Display Terraform outputs:

```bash
terraform output
```

Connect using SSH:

```bash
ssh -i ~/.ssh/id_rsa admin@<VM-IP>
```

The `admin` user is configured through cloud-init and authenticated using the SSH public key specified in Terraform.

Alternatively:

```bash
multipass shell tf-vm01
```

## Notes

- Terraform manages VM lifecycle; Multipass provides local virtualization.
- Cloud-init handles user creation, SSH configuration, package installation and initial provisioning.
- Provisioning scripts are executed during initial VM setup.
- Custom images can be stored locally or downloaded from remote HTTP/HTTPS sources.
- Do not commit `.terraform/`, Terraform state files, private SSH keys to GitHub.
- Terraform state should be backed up if it contains important infrastructure information.
