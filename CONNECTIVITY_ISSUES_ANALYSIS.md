# Connectivity Issues Analysis - 207.127.99.200:80

## Summary
You cannot access the load balancer on port 80 due to **multiple critical configuration mismatches** between the app code, NSG rules, and deployment configuration.

---

## Issues Found

### ⚠️ CRITICAL ISSUE #1: Database Backend Connection Port Mismatch
**Location:** [security_groups.tf](security_groups.tf#L319-L334)

```terraform
# Backend to DB rule expects MySQL port 3306
tcp_options {
  destination_port_range {
    min = 3306
    max = 3306
  }
}
```

**But:** [deploy.sh](deploy.sh#L136) configures PostgreSQL:
```bash
POSTGRES_HOST=$DATABASE_IP
POSTGRES_PORT=5432
```

**Problem:** The NSG rule only allows port 3306 (MySQL), but the deployment uses port 5432 (PostgreSQL). The backend cannot communicate with the database.

**Fix:** Change port range in backend-to-db NSG rule from 3306 to 5432

---

### ⚠️ CRITICAL ISSUE #2: Frontend Egress Rule Missing for Backend Connection
**Location:** [security_groups.tf](security_groups.tf#L273-L294)

The frontend NSG rule for backend connectivity is incomplete:
```terraform
resource "oci_core_network_security_group_security_rule" "frontend_to_backend" {
  # Only allows TCP port 8080 egress to backend
  tcp_options {
    destination_port_range {
      min = 8080
      max = 8080
    }
  }
}
```

**But:** [deploy.sh](deploy.sh#L114) shows the vote service also needs to reach Redis on port 6379:
```bash
Environment="REDIS_HOST=$BACKEND_IP"
Environment="REDIS_PORT=6379"
```

**Problem:** Frontend can only reach backend on port 8080, but can't reach Redis on 6379.

**Fix:** Add another egress rule for port 6379 to backend, OR expand the existing rule to include 6379.

---

### ⚠️ CRITICAL ISSUE #3: Backend Egress to Database Missing
**Location:** [security_groups.tf](security_groups.tf#L301-L317)

Backend to DB egress rule expects MySQL (3306), but should be PostgreSQL (5432).

**Fix:** Change port 3306 to 5432

---

### ⚠️ ISSUE #4: Database Incoming Rule Wrong Port
**Location:** [security_groups.tf](security_groups.tf#L331-L346)

```terraform
resource "oci_core_network_security_group_security_rule" "db_from_backend" {
  tcp_options {
    destination_port_range {
      min = 3306
      max = 3306
    }
  }
}
```

**Problem:** Expects MySQL port 3306, but should accept PostgreSQL port 5432

**Fix:** Change port 3306 to 5432

---

### ⚠️ ISSUE #5: Load Balancer NSG - Missing Backend Set Port
**Location:** [security_groups.tf](security_groups.tf#L110-L124)

The LB forward rule to frontend looks correct (8080-8081), but:
```terraform
resource "oci_core_network_security_group_security_rule" "lb_to_frontend" {
  tcp_options {
    destination_port_range {
      min = 8080
      max = 8081
    }
  }
}
```

**Problem:** This allows port 8081 to frontend, but the application only listens on:
- **Vote (vote/app.py):** Port 8080 (line 40: `PORT = int(os.getenv('VOTE_PORT', '8080'))`)
- **Result (result/server.js):** Port 4000 or env var (line 9: `var port = process.env.PORT || 4000;`)

The load balancer listener is configured for port 80 → backend on 8080 (correct), but result service defaults to 4000 which isn't exposed.

**Fix:** Either:
1. Explicitly set `PORT=8081` in result service environment, OR
2. The result service should be separate from the voting service

---

## Port Summary Table

| Component | Port | Type | Issue |
|-----------|------|------|-------|
| Load Balancer | 80 | Public Ingress | ✓ Correct |
| Vote App | 8080 | Frontend | ✓ Correct |
| Result App | 4000 (default) or 8081 | Frontend | ✗ Mismatch |
| Redis | 6379 | Backend | ✗ Missing NSG egress rule from Frontend |
| PostgreSQL | 5432 | Database | ✗ NSG rules use 3306 (MySQL) |

---

## Recommended Fixes

### Fix 1: Update Database Port Rules
Change all database NSG rules from port 3306 to 5432:
- `backend_to_db`: 3306 → 5432
- `db_from_backend`: 3306 → 5432

### Fix 2: Add Redis Port to Frontend Egress
Add or expand frontend-to-backend rule to include port 6379

### Fix 3: Verify Result Service Port Configuration
Ensure `PORT=8081` is set in the result service environment during deployment

---

## Verification Checklist

- [ ] Database NSG rules changed from 3306 to 5432
- [ ] Frontend can reach both Redis (6379) and app (8080) on backend
- [ ] Result service port matches LB configuration
- [ ] Terraform reapplied (`terraform apply`)
- [ ] Test connectivity: `curl http://207.127.99.200:80`
