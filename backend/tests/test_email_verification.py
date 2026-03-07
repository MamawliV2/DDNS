"""
Email Verification Flow Tests
Tests for: register, verify, resend-code, login with verification status
"""
import pytest
import requests
import os
import uuid

BASE_URL = os.environ.get('REACT_APP_BACKEND_URL', '').rstrip('/')
if not BASE_URL:
    BASE_URL = "https://dns-deploy.preview.emergentagent.com"

API = f"{BASE_URL}/api"


class TestHealthCheck:
    """Health check - run first"""
    
    def test_health_endpoint(self):
        response = requests.get(f"{API}/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        print("✓ Health check passed")


class TestRegisterEndpoint:
    """Tests for POST /api/auth/register"""
    
    def test_register_new_user_returns_verification_status(self):
        """Register should return verification status, NOT token"""
        unique_email = f"test_verify_{uuid.uuid4().hex[:8]}@gmail.com"
        response = requests.post(f"{API}/auth/register", json={
            "email": unique_email,
            "password": "testpass123"
        })
        
        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
        data = response.json()
        
        # Should return verification status, not token
        assert "token" not in data, "Register should NOT return token (email not verified yet)"
        assert "email" in data
        assert data["email"] == unique_email
        assert "verified" in data
        assert data["verified"] == False
        assert "message" in data
        print(f"✓ Register returned verification status for {unique_email}")
    
    def test_register_invalid_email_format(self):
        """Register should reject invalid email format"""
        response = requests.post(f"{API}/auth/register", json={
            "email": "invalid-email",
            "password": "testpass123"
        })
        assert response.status_code == 400
        print("✓ Invalid email format rejected")
    
    def test_register_non_gmail_rejected(self):
        """Register should only allow Gmail addresses"""
        response = requests.post(f"{API}/auth/register", json={
            "email": "test@yahoo.com",
            "password": "testpass123"
        })
        assert response.status_code == 400
        data = response.json()
        assert "gmail" in data.get("detail", "").lower() or "gmail" in str(data).lower()
        print("✓ Non-Gmail address rejected")
    
    def test_register_password_too_short(self):
        """Register should reject passwords less than 6 chars"""
        response = requests.post(f"{API}/auth/register", json={
            "email": f"test_{uuid.uuid4().hex[:8]}@gmail.com",
            "password": "12345"
        })
        assert response.status_code == 422, f"Expected 422 for short password, got {response.status_code}"
        print("✓ Short password rejected")


class TestVerifyEndpoint:
    """Tests for POST /api/auth/verify"""
    
    def test_verify_wrong_code_returns_400(self):
        """Verify with wrong code should return 400"""
        # First register a user
        unique_email = f"test_wrongcode_{uuid.uuid4().hex[:8]}@gmail.com"
        reg_response = requests.post(f"{API}/auth/register", json={
            "email": unique_email,
            "password": "testpass123"
        })
        assert reg_response.status_code == 200
        
        # Try to verify with wrong code
        verify_response = requests.post(f"{API}/auth/verify", json={
            "email": unique_email,
            "code": "000000"  # Wrong code
        })
        
        assert verify_response.status_code == 400
        data = verify_response.json()
        assert "invalid" in data.get("detail", "").lower() or "code" in data.get("detail", "").lower()
        print(f"✓ Wrong verification code rejected for {unique_email}")
    
    def test_verify_nonexistent_user_returns_404(self):
        """Verify for non-existent user should return 404"""
        response = requests.post(f"{API}/auth/verify", json={
            "email": "nonexistent_user_test@gmail.com",
            "code": "123456"
        })
        
        assert response.status_code == 404
        data = response.json()
        assert "not found" in data.get("detail", "").lower()
        print("✓ Non-existent user returns 404")
    
    def test_verify_missing_fields(self):
        """Verify should require both email and code"""
        # Missing code
        response = requests.post(f"{API}/auth/verify", json={
            "email": "test@gmail.com"
        })
        assert response.status_code == 422
        
        # Missing email
        response = requests.post(f"{API}/auth/verify", json={
            "code": "123456"
        })
        assert response.status_code == 422
        print("✓ Missing fields rejected")


class TestResendCodeEndpoint:
    """Tests for POST /api/auth/resend-code"""
    
    def test_resend_code_for_unverified_user(self):
        """Resend code should work for unverified users"""
        # First register a user
        unique_email = f"test_resend_{uuid.uuid4().hex[:8]}@gmail.com"
        reg_response = requests.post(f"{API}/auth/register", json={
            "email": unique_email,
            "password": "testpass123"
        })
        assert reg_response.status_code == 200
        
        # Resend code
        resend_response = requests.post(f"{API}/auth/resend-code", json={
            "email": unique_email
        })
        
        assert resend_response.status_code == 200
        data = resend_response.json()
        assert "message" in data
        print(f"✓ Resend code worked for {unique_email}")
    
    def test_resend_code_nonexistent_user_returns_404(self):
        """Resend code for non-existent user should return 404"""
        response = requests.post(f"{API}/auth/resend-code", json={
            "email": "nonexistent_resend_test@gmail.com"
        })
        
        assert response.status_code == 404
        print("✓ Resend code for non-existent user returns 404")


class TestLoginWithVerification:
    """Tests for POST /api/auth/login with verification status"""
    
    def test_login_unverified_user_returns_403(self):
        """Login for unverified user should return 403"""
        # First register a user (will be unverified)
        unique_email = f"test_unverified_{uuid.uuid4().hex[:8]}@gmail.com"
        reg_response = requests.post(f"{API}/auth/register", json={
            "email": unique_email,
            "password": "testpass123"
        })
        assert reg_response.status_code == 200
        
        # Try to login - should get 403
        login_response = requests.post(f"{API}/auth/login", json={
            "email": unique_email,
            "password": "testpass123"
        })
        
        assert login_response.status_code == 403, f"Expected 403 for unverified user, got {login_response.status_code}"
        data = login_response.json()
        assert "not verified" in data.get("detail", "").lower()
        print(f"✓ Unverified user login returns 403 for {unique_email}")
    
    def test_login_wrong_password_returns_401(self):
        """Login with wrong password should return 401"""
        # First register a user
        unique_email = f"test_wrongpwd_{uuid.uuid4().hex[:8]}@gmail.com"
        requests.post(f"{API}/auth/register", json={
            "email": unique_email,
            "password": "testpass123"
        })
        
        # Try login with wrong password
        login_response = requests.post(f"{API}/auth/login", json={
            "email": unique_email,
            "password": "wrongpassword"
        })
        
        assert login_response.status_code == 401
        print("✓ Wrong password returns 401")
    
    def test_login_nonexistent_user_returns_401(self):
        """Login for non-existent user should return 401"""
        response = requests.post(f"{API}/auth/login", json={
            "email": "doesnotexist_login_test@gmail.com",
            "password": "somepassword"
        })
        
        assert response.status_code == 401
        print("✓ Non-existent user login returns 401")


class TestVerifiedUserLogin:
    """Test that verified user can login with token"""
    
    def test_verified_user_gets_token(self):
        """Test login flow with verified user (using test admin)"""
        # testadmin@gmail.com is verified in this iteration
        login_response = requests.post(f"{API}/auth/login", json={
            "email": "testadmin@gmail.com",
            "password": "adminpass123"
        })
        
        assert login_response.status_code == 200
        data = login_response.json()
        assert "token" in data
        assert "user" in data
        assert data["user"]["email"] == "testadmin@gmail.com"
        print("✓ Verified user login returns token")
    
    def test_verified_user_reregister_fails(self):
        """Re-registering verified user should return 400 'Email already registered'"""
        response = requests.post(f"{API}/auth/register", json={
            "email": "testadmin@gmail.com",
            "password": "differentpassword"
        })
        
        assert response.status_code == 400
        data = response.json()
        assert "already registered" in data.get("detail", "").lower()
        print("✓ Verified user re-register returns 'Email already registered'")


class TestExistingUserReRegister:
    """Test re-registration behavior"""
    
    def test_unverified_user_reregister_sends_new_code(self):
        """Re-registering unverified user should send new code"""
        unique_email = f"test_reregister_{uuid.uuid4().hex[:8]}@gmail.com"
        
        # First registration
        reg1 = requests.post(f"{API}/auth/register", json={
            "email": unique_email,
            "password": "testpass123"
        })
        assert reg1.status_code == 200
        
        # Second registration - should succeed and send new code
        reg2 = requests.post(f"{API}/auth/register", json={
            "email": unique_email,
            "password": "newpassword123"  # Can change password too
        })
        
        assert reg2.status_code == 200
        data = reg2.json()
        assert data.get("verified") == False
        assert "message" in data
        print(f"✓ Unverified user re-register works for {unique_email}")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
