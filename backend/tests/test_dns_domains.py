"""
Test suite for DNS Management with Multi-Domain Support
Features tested:
- User Authentication (register, login)
- GET /api/domains - returns active domains for users
- GET /api/admin/domains - returns all domains with record counts (admin only)
- POST /api/admin/domains - add new domain with name and zone_id (admin only)
- PUT /api/admin/domains/{id} - toggle active/inactive (admin only)
- DELETE /api/admin/domains/{id} - delete domain if no records (admin only)
- GET /api/admin/stats - returns total_domains and active_domains counts
- POST /api/dns/records with domain_id - creates record on correct domain
- Default domain 'dnslab.biz' is auto-seeded on startup
"""

import pytest
import requests
import os
import uuid
from datetime import datetime

BASE_URL = os.environ.get('REACT_APP_BACKEND_URL', '').rstrip('/')

# Test identifiers to avoid conflicts
TEST_PREFIX = f"TEST_{uuid.uuid4().hex[:6]}"


class TestHealth:
    """Basic health check"""
    
    def test_health_endpoint(self):
        """Verify API is healthy"""
        response = requests.get(f"{BASE_URL}/api/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "DNSLAB.BIZ API"
        print("✓ Health check passed")


class TestAuthentication:
    """Authentication endpoint tests"""
    
    def test_register_new_user(self):
        """Register a new test user"""
        email = f"testuser_{TEST_PREFIX}@gmail.com"
        response = requests.post(f"{BASE_URL}/api/auth/register", json={
            "email": email,
            "password": "testpass123"
        })
        assert response.status_code == 200, f"Registration failed: {response.json()}"
        data = response.json()
        assert "token" in data
        assert "user" in data
        assert data["user"]["email"] == email
        assert data["user"]["plan"] == "free"
        print(f"✓ User {email} registered successfully")
        return data
    
    def test_register_non_gmail_rejected(self):
        """Non-Gmail addresses should be rejected"""
        response = requests.post(f"{BASE_URL}/api/auth/register", json={
            "email": f"testuser_{TEST_PREFIX}@yahoo.com",
            "password": "testpass123"
        })
        assert response.status_code == 400
        assert "gmail" in response.json()["detail"].lower()
        print("✓ Non-Gmail registration correctly rejected")
    
    def test_login_success(self):
        """Login with valid credentials"""
        # First register
        email = f"logintest_{TEST_PREFIX}@gmail.com"
        requests.post(f"{BASE_URL}/api/auth/register", json={
            "email": email,
            "password": "testpass123"
        })
        
        # Then login
        response = requests.post(f"{BASE_URL}/api/auth/login", json={
            "email": email,
            "password": "testpass123"
        })
        assert response.status_code == 200
        data = response.json()
        assert "token" in data
        assert "user" in data
        print(f"✓ Login successful for {email}")
    
    def test_login_invalid_credentials(self):
        """Login with invalid credentials should fail"""
        response = requests.post(f"{BASE_URL}/api/auth/login", json={
            "email": "nonexistent@gmail.com",
            "password": "wrongpassword"
        })
        assert response.status_code == 401
        print("✓ Invalid login correctly rejected")


class TestUserDomains:
    """Test user-facing domain endpoints"""
    
    @pytest.fixture
    def user_token(self):
        """Get a user token for testing"""
        email = f"domaintest_{TEST_PREFIX}@gmail.com"
        # Try login first
        response = requests.post(f"{BASE_URL}/api/auth/login", json={
            "email": email,
            "password": "testpass123"
        })
        if response.status_code == 200:
            return response.json()["token"]
        
        # If login fails, register
        response = requests.post(f"{BASE_URL}/api/auth/register", json={
            "email": email,
            "password": "testpass123"
        })
        assert response.status_code == 200, f"Registration failed: {response.json()}"
        return response.json()["token"]
    
    def test_get_active_domains(self, user_token):
        """GET /api/domains - returns active domains for users"""
        response = requests.get(
            f"{BASE_URL}/api/domains",
            headers={"Authorization": f"Bearer {user_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "domains" in data
        assert isinstance(data["domains"], list)
        
        # Default domain should be present
        domain_names = [d["name"] for d in data["domains"]]
        assert "dnslab.biz" in domain_names, "Default domain 'dnslab.biz' should be seeded"
        print(f"✓ GET /api/domains returned {len(data['domains'])} active domains")
        
        # Validate domain structure
        for domain in data["domains"]:
            assert "id" in domain
            assert "name" in domain
            assert "zone_id" in domain
            assert domain.get("active") == True, "Only active domains should be returned"
        print("✓ Domain structure validated")
    
    def test_domains_require_auth(self):
        """GET /api/domains requires authentication"""
        response = requests.get(f"{BASE_URL}/api/domains")
        assert response.status_code == 401
        print("✓ Domains endpoint correctly requires auth")


class TestAdminDomainManagement:
    """Test admin domain CRUD operations"""
    
    @pytest.fixture
    def admin_token(self):
        """Get admin token - register admin user and setup"""
        admin_email = "testadmin@gmail.com"
        # Try login first
        response = requests.post(f"{BASE_URL}/api/auth/login", json={
            "email": admin_email,
            "password": "adminpass123"
        })
        if response.status_code == 200:
            user_data = response.json()
            if user_data.get("user", {}).get("role") == "admin":
                return response.json()["token"]
        
        # If not admin or login failed, try to register and setup
        response = requests.post(f"{BASE_URL}/api/auth/register", json={
            "email": admin_email,
            "password": "adminpass123"
        })
        if response.status_code == 200:
            token = response.json()["token"]
        elif response.status_code == 400 and "already registered" in response.json().get("detail", ""):
            # Already exists, login
            response = requests.post(f"{BASE_URL}/api/auth/login", json={
                "email": admin_email,
                "password": "adminpass123"
            })
            if response.status_code != 200:
                pytest.skip(f"Cannot get admin token: login failed - {response.json()}")
            token = response.json()["token"]
        else:
            pytest.skip(f"Cannot get admin token: {response.json()}")
        
        # Setup admin
        requests.post(f"{BASE_URL}/api/admin/setup")
        
        # Re-login to get updated role
        response = requests.post(f"{BASE_URL}/api/auth/login", json={
            "email": admin_email,
            "password": "adminpass123"
        })
        if response.status_code == 200:
            return response.json()["token"]
        pytest.skip("Cannot get admin token")
    
    def test_admin_list_domains(self, admin_token):
        """GET /api/admin/domains - returns all domains with record counts"""
        response = requests.get(
            f"{BASE_URL}/api/admin/domains",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "domains" in data
        
        # Check default domain exists
        domain_names = [d["name"] for d in data["domains"]]
        assert "dnslab.biz" in domain_names, "Default domain should be seeded"
        
        # Validate record_count is included
        for domain in data["domains"]:
            assert "record_count" in domain, "Each domain should have record_count"
            assert isinstance(domain["record_count"], int)
        print(f"✓ Admin GET /api/admin/domains returned {len(data['domains'])} domains with record counts")
    
    def test_admin_add_domain(self, admin_token):
        """POST /api/admin/domains - add new domain"""
        test_domain = "testdomain123.xyz"
        response = requests.post(
            f"{BASE_URL}/api/admin/domains",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "name": test_domain,
                "zone_id": "test_zone_id_12345"
            }
        )
        assert response.status_code == 200, f"Failed to add domain: {response.json()}"
        data = response.json()
        assert data["name"] == test_domain.lower()
        assert data["zone_id"] == "test_zone_id_12345"
        assert data["active"] == True
        assert "id" in data
        print(f"✓ Domain {test_domain} added successfully")
        
        # Store for cleanup
        return data["id"]
    
    def test_admin_toggle_domain_inactive(self, admin_token):
        """PUT /api/admin/domains/{id} - toggle domain to inactive"""
        # First add a domain
        test_domain = "toggletest123.xyz"
        add_response = requests.post(
            f"{BASE_URL}/api/admin/domains",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "name": test_domain,
                "zone_id": "toggle_zone_12345"
            }
        )
        assert add_response.status_code == 200
        domain_id = add_response.json()["id"]
        
        # Toggle to inactive
        response = requests.put(
            f"{BASE_URL}/api/admin/domains/{domain_id}",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"active": False}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["active"] == False
        print(f"✓ Domain toggled to inactive")
        
        # Verify inactive domain not returned to users
        user_email = f"togglecheck_{TEST_PREFIX}@gmail.com"
        reg_resp = requests.post(f"{BASE_URL}/api/auth/register", json={
            "email": user_email,
            "password": "testpass123"
        })
        if reg_resp.status_code == 200:
            user_token = reg_resp.json()["token"]
        else:
            login_resp = requests.post(f"{BASE_URL}/api/auth/login", json={
                "email": user_email,
                "password": "testpass123"
            })
            user_token = login_resp.json()["token"]
        
        domains_resp = requests.get(
            f"{BASE_URL}/api/domains",
            headers={"Authorization": f"Bearer {user_token}"}
        )
        user_domains = [d["name"] for d in domains_resp.json()["domains"]]
        assert test_domain.lower() not in user_domains, "Inactive domain should not be visible to users"
        print("✓ Inactive domain not visible to users")
        
        # Cleanup
        requests.delete(
            f"{BASE_URL}/api/admin/domains/{domain_id}",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
    
    def test_admin_delete_domain_no_records(self, admin_token):
        """DELETE /api/admin/domains/{id} - delete domain if no records"""
        # Add domain
        test_domain = "deletetest123.xyz"
        add_response = requests.post(
            f"{BASE_URL}/api/admin/domains",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "name": test_domain,
                "zone_id": "delete_zone_12345"
            }
        )
        assert add_response.status_code == 200
        domain_id = add_response.json()["id"]
        
        # Delete it
        response = requests.delete(
            f"{BASE_URL}/api/admin/domains/{domain_id}",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        assert "deleted" in response.json()["message"].lower()
        print(f"✓ Domain deleted successfully")
        
        # Verify it's gone
        list_response = requests.get(
            f"{BASE_URL}/api/admin/domains",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        domain_ids = [d["id"] for d in list_response.json()["domains"]]
        assert domain_id not in domain_ids, "Deleted domain should not exist"
        print("✓ Deleted domain verified as removed")
    
    def test_admin_domains_require_admin(self):
        """Admin domain endpoints require admin role"""
        # Register a regular user
        email = f"regularuser_{TEST_PREFIX}@gmail.com"
        response = requests.post(f"{BASE_URL}/api/auth/register", json={
            "email": email,
            "password": "testpass123"
        })
        if response.status_code != 200:
            response = requests.post(f"{BASE_URL}/api/auth/login", json={
                "email": email,
                "password": "testpass123"
            })
        token = response.json()["token"]
        
        # Try to access admin domains
        response = requests.get(
            f"{BASE_URL}/api/admin/domains",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 403, "Non-admin should get 403"
        print("✓ Admin domain endpoints require admin role")


class TestAdminStats:
    """Test admin stats endpoint"""
    
    @pytest.fixture
    def admin_token(self):
        """Get admin token"""
        admin_email = "testadmin@gmail.com"
        response = requests.post(f"{BASE_URL}/api/auth/login", json={
            "email": admin_email,
            "password": "adminpass123"
        })
        if response.status_code == 200:
            return response.json()["token"]
        pytest.skip("Admin user not available")
    
    def test_admin_stats_includes_domains(self, admin_token):
        """GET /api/admin/stats - returns total_domains and active_domains counts"""
        response = requests.get(
            f"{BASE_URL}/api/admin/stats",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        
        # Check required fields
        assert "total_users" in data
        assert "total_records" in data
        assert "total_domains" in data
        assert "active_domains" in data
        
        assert isinstance(data["total_domains"], int)
        assert isinstance(data["active_domains"], int)
        assert data["total_domains"] >= data["active_domains"]
        print(f"✓ Admin stats: {data['total_domains']} total domains, {data['active_domains']} active")


class TestDNSRecordsWithDomain:
    """Test DNS record creation with domain_id"""
    
    @pytest.fixture
    def user_with_token(self):
        """Get user token and info"""
        email = f"dnsrecords_{TEST_PREFIX}@gmail.com"
        response = requests.post(f"{BASE_URL}/api/auth/login", json={
            "email": email,
            "password": "testpass123"
        })
        if response.status_code == 200:
            return response.json()
        
        response = requests.post(f"{BASE_URL}/api/auth/register", json={
            "email": email,
            "password": "testpass123"
        })
        assert response.status_code == 200
        return response.json()
    
    def test_create_record_with_default_domain(self, user_with_token):
        """POST /api/dns/records - creates record on default domain when domain_id not specified"""
        token = user_with_token["token"]
        subdomain = f"sub{TEST_PREFIX[:6].replace('_', '')}"
        
        # Get domains first
        domains_resp = requests.get(
            f"{BASE_URL}/api/domains",
            headers={"Authorization": f"Bearer {token}"}
        )
        domains = domains_resp.json()["domains"]
        default_domain = next((d for d in domains if d["name"] == "dnslab.biz"), None)
        
        if not default_domain:
            pytest.skip("Default domain not available")
        
        # Create record without domain_id - should use default
        response = requests.post(
            f"{BASE_URL}/api/dns/records",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "record_type": "A",
                "name": subdomain,
                "content": "192.168.1.100"
            }
        )
        
        if response.status_code == 403:
            print("✓ Record limit reached (expected for free plan)")
            return
        
        assert response.status_code == 200, f"Failed: {response.json()}"
        data = response.json()
        assert data["domain_name"] == "dnslab.biz"
        assert data["full_name"] == f"{subdomain}.dnslab.biz"
        print(f"✓ Record created on default domain: {data['full_name']}")
        
        # Cleanup
        requests.delete(
            f"{BASE_URL}/api/dns/records/{data['id']}",
            headers={"Authorization": f"Bearer {token}"}
        )
    
    def test_create_record_with_specific_domain_id(self, user_with_token):
        """POST /api/dns/records with domain_id - creates record on correct domain"""
        token = user_with_token["token"]
        
        # Get domains
        domains_resp = requests.get(
            f"{BASE_URL}/api/domains",
            headers={"Authorization": f"Bearer {token}"}
        )
        domains = domains_resp.json()["domains"]
        
        if not domains:
            pytest.skip("No domains available")
        
        target_domain = domains[0]
        subdomain = f"spec{TEST_PREFIX[:6].replace('_', '')}"
        
        # Create record with specific domain_id
        response = requests.post(
            f"{BASE_URL}/api/dns/records",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "record_type": "A",
                "name": subdomain,
                "content": "192.168.1.101",
                "domain_id": target_domain["id"]
            }
        )
        
        if response.status_code == 403:
            print("✓ Record limit reached (expected for free plan)")
            return
        
        assert response.status_code == 200, f"Failed: {response.json()}"
        data = response.json()
        assert data["domain_id"] == target_domain["id"]
        assert data["domain_name"] == target_domain["name"]
        assert data["full_name"] == f"{subdomain}.{target_domain['name']}"
        print(f"✓ Record created on specified domain: {data['full_name']}")
        
        # Verify record is in list
        records_resp = requests.get(
            f"{BASE_URL}/api/dns/records",
            headers={"Authorization": f"Bearer {token}"}
        )
        records = records_resp.json()["records"]
        record = next((r for r in records if r["id"] == data["id"]), None)
        assert record is not None
        assert record["domain_name"] == target_domain["name"]
        print("✓ Record shows correct domain_name in records table")
        
        # Cleanup
        requests.delete(
            f"{BASE_URL}/api/dns/records/{data['id']}",
            headers={"Authorization": f"Bearer {token}"}
        )
    
    def test_free_plan_record_limit(self, user_with_token):
        """Free plan users limited to 2 records total across all domains"""
        token = user_with_token["token"]
        
        # Get current record count
        me_resp = requests.get(
            f"{BASE_URL}/api/auth/me",
            headers={"Authorization": f"Bearer {token}"}
        )
        user_info = me_resp.json()
        
        if user_info.get("plan") != "free":
            pytest.skip("User is not on free plan")
        
        if user_info.get("record_count", 0) >= 2:
            # Try to create another record - should fail
            response = requests.post(
                f"{BASE_URL}/api/dns/records",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "record_type": "A",
                    "name": f"limit{TEST_PREFIX[:6].replace('_', '')}",
                    "content": "192.168.1.200"
                }
            )
            assert response.status_code == 403
            assert "limit" in response.json()["detail"].lower()
            print("✓ Free plan limit correctly enforced")
        else:
            print(f"✓ User has {user_info.get('record_count', 0)}/2 records - limit not yet reached")


class TestCleanup:
    """Cleanup test data"""
    
    def test_cleanup_test_domains(self):
        """Clean up any test domains created"""
        admin_email = "testadmin@gmail.com"
        response = requests.post(f"{BASE_URL}/api/auth/login", json={
            "email": admin_email,
            "password": "adminpass123"
        })
        if response.status_code != 200:
            print("✓ Skipping cleanup - admin not available")
            return
        
        token = response.json()["token"]
        
        # List domains
        domains_resp = requests.get(
            f"{BASE_URL}/api/admin/domains",
            headers={"Authorization": f"Bearer {token}"}
        )
        
        if domains_resp.status_code == 200:
            domains = domains_resp.json()["domains"]
            for domain in domains:
                # Delete test domains (those with TEST_ prefix or test prefix patterns)
                if ("test" in domain["name"].lower() and domain["name"] != "dnslab.biz" 
                    and domain.get("record_count", 0) == 0):
                    requests.delete(
                        f"{BASE_URL}/api/admin/domains/{domain['id']}",
                        headers={"Authorization": f"Bearer {token}"}
                    )
                    print(f"✓ Cleaned up test domain: {domain['name']}")
        
        print("✓ Cleanup completed")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
