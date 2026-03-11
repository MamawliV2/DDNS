"""
Backend tests for DNS Management UI - Testing 4 UI/UX Features
- Health check endpoint
- Register endpoint (for Telegram notification - code structure verification)
- Auth endpoints
"""
import pytest
import requests
import os

BASE_URL = os.environ.get('REACT_APP_BACKEND_URL', '').rstrip('/')

class TestHealthEndpoint:
    """Health check endpoint tests"""
    
    def test_health_endpoint_returns_200(self):
        """Test /api/health returns 200 with healthy status"""
        response = requests.get(f"{BASE_URL}/api/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "DNSLAB.BIZ API"
        print("✓ Health endpoint working correctly")


class TestAuthEndpoints:
    """Authentication endpoint tests"""
    
    def test_register_returns_400_for_invalid_email_format(self):
        """Test register endpoint rejects invalid email format"""
        response = requests.post(f"{BASE_URL}/api/auth/register", json={
            "email": "invalidemail",
            "password": "password123"
        })
        assert response.status_code == 400
        data = response.json()
        assert "Invalid email" in data.get("detail", "")
        print("✓ Register rejects invalid email format")
    
    def test_register_requires_gmail(self):
        """Test register endpoint only allows Gmail addresses"""
        response = requests.post(f"{BASE_URL}/api/auth/register", json={
            "email": "test@yahoo.com",
            "password": "password123"
        })
        assert response.status_code == 400
        data = response.json()
        assert "Gmail" in data.get("detail", "") or "gmail.com" in data.get("detail", "")
        print("✓ Register requires Gmail addresses")
    
    def test_login_returns_401_for_invalid_credentials(self):
        """Test login returns 401 for non-existent user"""
        response = requests.post(f"{BASE_URL}/api/auth/login", json={
            "email": "nonexistent_user_test@gmail.com",
            "password": "wrongpassword123"
        })
        assert response.status_code == 401
        data = response.json()
        assert "Invalid email or password" in data.get("detail", "")
        print("✓ Login rejects invalid credentials")
    
    def test_login_requires_email_and_password(self):
        """Test login endpoint validation"""
        # Missing password
        response = requests.post(f"{BASE_URL}/api/auth/login", json={
            "email": "test@gmail.com"
        })
        assert response.status_code == 422  # Validation error
        print("✓ Login requires all fields")
    
    def test_verify_endpoint_returns_404_for_unknown_user(self):
        """Test verify endpoint returns 404 for unknown email"""
        response = requests.post(f"{BASE_URL}/api/auth/verify", json={
            "email": "unknownuser_test@gmail.com",
            "code": "123456"
        })
        assert response.status_code == 404
        print("✓ Verify returns 404 for unknown user")
    
    def test_resend_code_returns_404_for_unknown_user(self):
        """Test resend-code endpoint returns 404 for unknown email"""
        response = requests.post(f"{BASE_URL}/api/auth/resend-code", json={
            "email": "unknownuser_resend_test@gmail.com"
        })
        assert response.status_code == 404
        print("✓ Resend-code returns 404 for unknown user")


class TestDNSEndpoints:
    """DNS record endpoints authentication tests"""
    
    def test_dns_records_requires_authentication(self):
        """Test /api/dns/records requires auth"""
        response = requests.get(f"{BASE_URL}/api/dns/records")
        assert response.status_code == 401
        print("✓ DNS records endpoint requires authentication")
    
    def test_dns_create_requires_authentication(self):
        """Test creating DNS record requires auth"""
        response = requests.post(f"{BASE_URL}/api/dns/records", json={
            "record_type": "A",
            "name": "test",
            "content": "192.168.1.1"
        })
        assert response.status_code == 401
        print("✓ DNS create endpoint requires authentication")
    
    def test_domains_requires_authentication(self):
        """Test /api/domains requires auth"""
        response = requests.get(f"{BASE_URL}/api/domains")
        assert response.status_code == 401
        print("✓ Domains endpoint requires authentication")


class TestAuthMeEndpoint:
    """Auth me endpoint tests"""
    
    def test_auth_me_requires_authentication(self):
        """Test /api/auth/me requires auth"""
        response = requests.get(f"{BASE_URL}/api/auth/me")
        assert response.status_code == 401
        print("✓ Auth me endpoint requires authentication")
    
    def test_auth_me_rejects_invalid_token(self):
        """Test /api/auth/me rejects invalid token"""
        response = requests.get(f"{BASE_URL}/api/auth/me", headers={
            "Authorization": "Bearer invalid_token_123"
        })
        assert response.status_code == 401
        print("✓ Auth me rejects invalid token")


class TestAdminEndpoints:
    """Admin endpoints authentication tests"""
    
    def test_admin_domains_requires_admin_auth(self):
        """Test /api/admin/domains requires admin auth"""
        response = requests.get(f"{BASE_URL}/api/admin/domains")
        assert response.status_code == 401
        print("✓ Admin domains requires authentication")
    
    def test_admin_users_requires_admin_auth(self):
        """Test /api/admin/users requires admin auth"""
        response = requests.get(f"{BASE_URL}/api/admin/users")
        assert response.status_code == 401
        print("✓ Admin users requires authentication")
    
    def test_admin_stats_requires_admin_auth(self):
        """Test /api/admin/stats requires admin auth"""
        response = requests.get(f"{BASE_URL}/api/admin/stats")
        assert response.status_code == 401
        print("✓ Admin stats requires authentication")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
