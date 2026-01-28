# VPC Infrastructure Architecture

This diagram shows the complete VPC networking setup, including subnets, NAT Gateway, Internet Gateway, and routing configuration.

## Resource Dependencies & Relationships

```
                                    INTERNET
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │      aws_internet_gateway     │
                        │          "gateway"            │
                        └───────────────┬───────────────┘
                                        │
                         depends_on ────┤
                                        │
        ┌───────────────────────────────┴───────────────────────────────┐
        │                                                               │
        │                        aws_vpc "main"                         │
        │                     (CIDR: var.vpc_cidr)                      │
        │                                                               │
        │   ┌─────────────────────────┐   ┌─────────────────────────┐   │
        │   │   PUBLIC SUBNET         │   │   PRIVATE SUBNET        │   │
        │   │   aws_subnet            │   │   aws_subnet            │   │
        │   │   "public_subnet"       │   │   "private_subnet"      │   │
        │   │                         │   │                         │   │
        │   │  map_public_ip = true   │   │  (no public IP)         │   │
        │   │                         │   │                         │   │
        │   │  ┌───────────────────┐  │   │                         │   │
        │   │  │ aws_nat_gateway   │  │   │                         │   │
        │   │  │     "nat"         │──┼───┼─── outbound traffic ────┤   │
        │   │  │                   │  │   │                         │   │
        │   │  │  ┌─────────────┐  │  │   │                         │   │
        │   │  │  │ aws_eip     │  │  │   │                         │   │
        │   │  │  │  "main"     │  │  │   │                         │   │
        │   │  │  └─────────────┘  │  │   │                         │   │
        │   │  └───────────────────┘  │   │                         │   │
        │   └───────────┬─────────────┘   └────────────┬────────────┘   │
        │               │                              │                │
        └───────────────┼──────────────────────────────┼────────────────┘
                        │                              │
                        ▼                              ▼
        ┌───────────────────────────┐   ┌───────────────────────────────┐
        │ aws_route_table_association│   │ aws_route_table_association   │
        │ "public_subnet_association"│   │ "private_subnet_association"  │
        └───────────────┬───────────┘   └───────────────┬───────────────┘
                        │                               │
                        ▼                               ▼
        ┌───────────────────────────┐   ┌───────────────────────────────┐
        │   aws_route_table         │   │   aws_route_table             │
        │       "public"            │   │       "private"               │
        │                           │   │                               │
        │  route:                   │   │  route:                       │
        │  0.0.0.0/0 → IGW          │   │  0.0.0.0/0 → NAT Gateway      │
        └───────────────────────────┘   └───────────────────────────────┘
```

---

## Resource Creation Order

```
Level 0 (Foundation):
    └── aws_vpc.main

Level 1 (Requires VPC):
    ├── aws_internet_gateway.gateway ─────────┐
    ├── aws_subnet.public_subnet              │
    ├── aws_subnet.private_subnet             │
    ├── aws_route_table.public ───────────────┤ (needs IGW for route)
    └── aws_route_table.private ──────────────┼─(needs NAT for route)
                                              │
Level 2 (Requires IGW):                       │
    └── aws_eip.main ─────────────────────────┘
                  │
Level 3 (Requires EIP + Public Subnet + IGW):
    └── aws_nat_gateway.nat
              │
Level 4 (After NAT Gateway exists):
    └── aws_route_table.private (route to NAT)

Level 5 (Requires Subnet + Route Table):
    ├── aws_route_table_association.public_subnet_association
    └── aws_route_table_association.private_subnet_association
```

---

## Resource Breakdown

### 1. `aws_vpc.main` — Foundation

**Analogy:** Think of VPC as a large piece of land you purchased. All buildings (resources) must be built on this land.

- CIDR Block `var.vpc_cidr` determines how many IP addresses are available
- All other resources must exist within this VPC
- `enable_dns_support` and `enable_dns_hostnames` allow instances to get DNS hostnames

**Why needed:** Without VPC, there's no "home" for other resources.

---

### 2. `aws_internet_gateway.gateway` — Gateway to Internet

**Analogy:** This is the main gate from your property to the highway (internet).

- Connected directly to VPC via `vpc_id = aws_vpc.main.id`
- Allows traffic in and out to internet
- Only 1 IGW per VPC

**Why needed:**
- Public subnet needs IGW for direct internet access
- NAT Gateway also needs IGW to forward traffic to internet

---

### 3. `aws_subnet.public_subnet` — Public Zone

**Analogy:** This is the front yard of your house that people can see from the street.

- `map_public_ip_on_launch = true` → every instance automatically gets public IP
- Used for resources that must be accessible from internet (load balancer, bastion host)
- NAT Gateway must be placed in public subnet

**Why needed:**
- Location for NAT Gateway
- Resources that need public access

---

### 4. `aws_subnet.private_subnet` — Secure Zone

**Analogy:** This is the interior room of your house that people outside cannot see directly.

- No automatic public IP
- Instances here are safe from direct internet access
- Suitable for database, application server, backend services

**Why needed:**
- Security — databases should not be exposed to internet
- Best practice: separate application tiers

---

### 5. `aws_eip.main` — Static IP for NAT

**Analogy:** This is a fixed phone number that doesn't change.

- `domain = "vpc"` means this EIP is for use within VPC
- `depends_on = [aws_internet_gateway.gateway]` → must wait for IGW to exist first

**Why needed:**
- NAT Gateway requires an Elastic IP
- IP must be stable so external services can whitelist your IP

---

### 6. `aws_nat_gateway.nat` — Bridge from Private to Internet

**Analogy:** This is a receptionist who receives requests from interior rooms (private subnet), forwards them to the outside world, and returns the responses.

```
Private Instance → NAT Gateway → Internet Gateway → Internet
                      ↑
               (IP masked with EIP)
```

- `allocation_id = aws_eip.main.id` → use EIP as public IP
- `subnet_id = aws_subnet.public_subnet.id` → NAT must be in public subnet
- `depends_on = [aws_internet_gateway.gateway]` → IGW must exist first

**Why needed:**
- Private instances need to download updates, access external APIs
- But still cannot be accessed from outside (one-way traffic)

---

### 7. `aws_route_table.public` — Public Subnet Route Map

**Analogy:** This is GPS/map that tells traffic in public subnet: "If you want to go to internet (0.0.0.0/0), go through Internet Gateway."

```hcl
route {
  cidr_block = "0.0.0.0/0"      # all destinations
  gateway_id = aws_internet_gateway.gateway.id  # via IGW
}
```

**Why needed:**
- Subnet doesn't automatically know how to reach internet
- Route table provides routing instructions

---

### 8. `aws_route_table.private` — Private Subnet Route Map

**Analogy:** GPS for private subnet: "If you want to go to internet, go through NAT Gateway."

```hcl
route {
  cidr_block = "0.0.0.0/0"      # all destinations
  gateway_id = aws_nat_gateway.nat.id  # via NAT
}
```

**Why needed:**
- Private subnet needs different route (via NAT, not IGW directly)
- Ensures outbound traffic is masked with NAT IP

---

### 9 & 10. `aws_route_table_association` — Subnet & Route Table Connector

**Analogy:** This is a sign posted at the subnet entrance, saying "Use this map for navigation."

- Public subnet → use public route table
- Private subnet → use private route table

**Why needed:**
- Route table doesn't automatically apply to subnet
- Must be explicitly associated

---

## Traffic Flow Scenarios

### Scenario 1: Instance in Public Subnet Accessing Internet
```
[EC2 Public] → [Route Table Public] → [Internet Gateway] → [Internet]
                     ↓
              "0.0.0.0/0 via IGW"
```

### Scenario 2: Instance in Private Subnet Accessing Internet
```
[EC2 Private] → [Route Table Private] → [NAT Gateway] → [IGW] → [Internet]
                      ↓                      ↓
              "0.0.0.0/0 via NAT"    (IP jadi EIP)
```

### Scenario 3: Internet Attempting to Access Private Instance
```
[Internet] → [IGW] → ❌ BLOCKED (no route to private subnet from outside)
```

---

## Impact of Missing Resources

| Missing Resource | Impact |
|-----------------|--------|
| VPC | All resources fail to create |
| Internet Gateway | No internet access at all |
| NAT Gateway | Private instances cannot access internet |
| EIP | NAT Gateway fails to create |
| Route Table | Subnet doesn't know how to route traffic |
| Route Table Association | Subnet uses default route (no internet) |

---

## Summary

**VPC Infrastructure:**
- Standard 3-tier architecture in AWS
- Clear separation between public and private zones
- Enhanced security for backend services

**Key Components:**
1. ✅ VPC (10.0.0.0/16) - Foundation for all resources
2. ✅ Internet Gateway - Direct internet access
3. ✅ Public Subnet - Hosts NAT Gateway
4. ✅ Private Subnet - Secure zone for applications
5. ✅ NAT Gateway - One-way internet access for private resources
6. ✅ Route Tables - Traffic routing configuration

**Traffic Flow:**
- Public subnet → Internet Gateway → Internet
- Private subnet → NAT Gateway → Internet Gateway → Internet
- Internet → ❌ Cannot reach private subnet (blocked)