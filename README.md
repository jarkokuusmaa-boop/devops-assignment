# InternalBoard — DevOps Assignment

A production-style internal message board demonstrating a full DevOps pipeline:
**Terraform → Proxmox VMs → Ansible configuration → Docker containers → Flask + PostgreSQL**.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Proxmox VE Host                                            │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────┐ │
│  │    web-01        │  │    db-01         │  │ monitor-01 │ │
│  │  192.168.100.11  │  │  192.168.100.12  │  │.100.13     │ │
│  │                  │  │                  │  │            │ │
│  │ ┌─────────────┐ │  │  PostgreSQL 16   │  │ htop       │ │
│  │ │  Flask app  │─┼──┼─► port 5432      │  │ iotop      │ │
│  │ │  (Gunicorn) │ │  │                  │  │ node_exp.  │ │
│  │ └─────────────┘ │  └─────────────────┘  └────────────┘ │
│  │ ┌─────────────┐ │                                        │
│  │ │  Postgres   │ │  (local dev only — external DB in      │
│  │ │  (Docker)   │ │   docker-compose for standalone use)   │
│  │ └─────────────┘ │                                        │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Tool            | Version  | Install                                       |
|-----------------|----------|-----------------------------------------------|
| Terraform       | ≥ 1.6    | https://developer.hashicorp.com/terraform/install |
| Ansible         | ≥ 2.15   | `pip install ansible`                         |
| Docker          | ≥ 25     | https://docs.docker.com/get-docker/           |
| Docker Compose  | V2       | Bundled with Docker Desktop / `docker-compose-plugin` |
| Proxmox VE      | ≥ 8.x    | Running in your lab environment               |

---

## Repository Structure

```
devops-assignment/
├── README.md
├── studentapp/                  # Flask application
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── .dockerignore
│   └── templates/
│       └── index.html
├── terraform/                   # Infrastructure provisioning
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── ansible/                     # Configuration management
    ├── ansible.cfg
    ├── inventory.ini
    ├── site.yml
    ├── group_vars/
    │   └── all.yml
    └── roles/
        ├── web-01/
        │   ├── tasks/main.yml
        │   └── templates/docker-compose.yml.j2
        ├── db-01/
        │   └── tasks/main.yml
        └── monitor-01/
            └── tasks/main.yml
```

---

## Step 1 — Prepare Proxmox

### 1a. Download Ubuntu 24.04 Cloud Image

SSH into your Proxmox host and run:

```bash
# Download Ubuntu 24.04 cloud image
wget -P /var/lib/vz/template/iso/ \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Create a VM template (VMID 9000)
qm create 9000 --name ubuntu-2404-cloud --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1
qm template 9000
```

### 1b. Create a Proxmox API Token

In the Proxmox web UI:
1. Go to **Datacenter → Permissions → API Tokens**
2. Create a token for user `terraform@pam` with **Privilege Separation** disabled
3. Copy the token string — you will need it in `terraform.tfvars`

Grant the token permissions:
```bash
pveum aclmod / -token 'terraform@pam!terraform-token' -role PVEVMAdmin
pveum aclmod /storage -token 'terraform@pam!terraform-token' -role PVEDatastoreAdmin
```

---

## Step 2 — Terraform (Provision VMs)

```bash
cd terraform/

# Copy and edit your variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars          # Set your Proxmox URL, API token, IPs

# Initialise Terraform
terraform init

# Preview the plan
terraform plan

# Apply (creates web-01, db-01, monitor-01)
terraform apply
```

**Expected output:**
```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:
app_url      = "http://192.168.100.11:5000"
db01_ip      = "192.168.100.12"
monitor01_ip = "192.168.100.13"
web01_ip     = "192.168.100.11"
```

Wait ~2 minutes for cloud-init to complete on all VMs, then test SSH:
```bash
ssh ubuntu@192.168.100.11   # web-01
ssh ubuntu@192.168.100.12   # db-01
ssh ubuntu@192.168.100.13   # monitor-01
```

---

## Step 3 — Ansible (Configure Systems)

### 3a. Install required Ansible collections

```bash
cd ansible/
ansible-galaxy collection install community.general community.postgresql
```

### 3b. Copy application files into the role's files directory

The web-01 role expects the Flask app source to be present:

```bash
# From the project root
cp -r studentapp/app.py            ansible/roles/web-01/files/
cp -r studentapp/requirements.txt  ansible/roles/web-01/files/
cp -r studentapp/Dockerfile        ansible/roles/web-01/files/
cp -r studentapp/.dockerignore     ansible/roles/web-01/files/
cp -r studentapp/templates/        ansible/roles/web-01/files/
```

### 3c. Update inventory (if you changed IPs in Terraform)

Edit `ansible/inventory.ini` to match your `terraform.tfvars` IP addresses.

### 3d. Run the full playbook

```bash
cd ansible/
ansible-playbook -i inventory.ini site.yml
```

To run a single role only:
```bash
ansible-playbook -i inventory.ini site.yml --limit web
ansible-playbook -i inventory.ini site.yml --limit db
ansible-playbook -i inventory.ini site.yml --limit monitoring
```

---

## Step 4 — Verify Deployment

```bash
# Check Flask health endpoint
curl http://192.168.100.11:5000/healthz
# Expected: {"status": "ok"}

# Check the web UI
curl http://192.168.100.11:5000/
# Expected: HTML with the InternalBoard page

# Run the monitoring check script from monitor-01
ssh ubuntu@192.168.100.13 check-services

# Check containers on web-01
ssh ubuntu@192.168.100.11 docker ps
```

Open `http://192.168.100.11:5000` in your browser to use the application.

---

## Part 1 — Standalone Docker Development

You can also run the app locally without Proxmox/Ansible:

```bash
cd studentapp/

# Build images
docker compose build

# Start application (web + postgres)
docker compose up -d

# Verify running containers
docker ps

# Test application
curl http://localhost:5000/healthz
curl http://localhost:5000/

# View logs
docker compose logs -f

# Stop
docker compose down

# Stop and remove volumes (wipes database)
docker compose down -v
```

---

## Validation Checklist

| Requirement                          | How to verify                                      |
|--------------------------------------|----------------------------------------------------|
| ✅ Terraform provisions VMs          | `terraform apply` succeeds; VMs appear in Proxmox UI |
| ✅ Ansible configures systems        | `ansible-playbook site.yml` runs with no failures  |
| ✅ Docker containers build           | `docker ps` shows `internalboard-web` and `internalboard-db` running |
| ✅ Flask app accessible in browser   | `curl http://192.168.100.11:5000/` returns HTML    |
| ✅ PostgreSQL stores messages        | Submit a message via the UI; it persists after refresh |
| ✅ App survives container restart    | `docker compose restart web` — data still present  |
| ✅ Infrastructure reproducible       | `terraform destroy && terraform apply` → same result |

---

## Troubleshooting

### Containers won't start
```bash
docker compose logs web   # Check Flask logs
docker compose logs db    # Check PostgreSQL logs
```

### Flask can't reach database
```bash
# Verify DB container is healthy
docker inspect internalboard-db | grep -A5 Health

# Test connection manually
docker exec -it internalboard-web python -c \
  "import psycopg2; conn=psycopg2.connect(host='db',dbname='appdb',user='appuser',password='apppassword'); print('OK')"
```

### Ansible can't reach VMs
```bash
# Test connectivity
ansible all -i inventory.ini -m ping

# Check if cloud-init is done
ssh ubuntu@<IP> cloud-init status
```

### Terraform plan errors
- Ensure the Ubuntu template VMID (default 9000) exists on Proxmox
- Confirm your API token has sufficient privileges
- Verify the `proxmox_snippets_storage` datastore supports content type `snippets`

---

## Security Notes

> ⚠️ This project uses simplified credentials for a lab environment.
> For any real deployment:
> - Use `ansible-vault encrypt_string` for all passwords
> - Store `terraform.tfvars` outside version control (it's in `.gitignore`)
> - Replace `apppassword` with a randomly generated secret
> - Enable TLS on the Flask application (nginx reverse proxy + Let's Encrypt)
