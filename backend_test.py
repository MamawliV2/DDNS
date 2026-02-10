import requests
import sys
import time
from datetime import datetime
import json

class DDNSAPITester:
    def __init__(self, base_url="https://dns-hub.preview.emergentagent.com"):
        self.base_url = base_url
        self.token = None
        self.tests_run = 0
        self.tests_passed = 0
        self.test_results = []
        self.created_records = []  # Track created records for cleanup

    def log_test(self, name, success, status_code=None, error_msg=None):
        """Log test result"""
        self.tests_run += 1
        if success:
            self.tests_passed += 1
            print(f"✅ {name} - Status: {status_code}")
        else:
            print(f"❌ {name} - Failed: {error_msg}")
        
        self.test_results.append({
            "test": name,
            "success": success,
            "status_code": status_code,
            "error": error_msg
        })

    def run_test(self, name, method, endpoint, expected_status, data=None, auth=True):
        """Run a single API test"""
        url = f"{self.base_url}/{endpoint}"
        headers = {'Content-Type': 'application/json'}
        if auth and self.token:
            headers['Authorization'] = f'Bearer {self.token}'

        print(f"\n🔍 Testing {name}...")
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=headers, timeout=10)
            elif method == 'POST':
                response = requests.post(url, json=data, headers=headers, timeout=10)
            elif method == 'PUT':
                response = requests.put(url, json=data, headers=headers, timeout=10)
            elif method == 'DELETE':
                response = requests.delete(url, headers=headers, timeout=10)

            success = response.status_code == expected_status
            if success:
                self.log_test(name, True, response.status_code)
                try:
                    return success, response.json()
                except:
                    return success, {}
            else:
                error_msg = f"Expected {expected_status}, got {response.status_code}"
                try:
                    error_detail = response.json().get('detail', '')
                    if error_detail:
                        error_msg += f" - {error_detail}"
                except:
                    pass
                self.log_test(name, False, response.status_code, error_msg)
                return False, {}

        except requests.exceptions.Timeout:
            self.log_test(name, False, None, "Request timeout")
            return False, {}
        except Exception as e:
            self.log_test(name, False, None, str(e))
            return False, {}

    def test_health(self):
        """Test health endpoint"""
        return self.run_test("Health Check", "GET", "api/health", 200, auth=False)

    def test_register(self, email, password, expected_status=200):
        """Test user registration"""
        success, response = self.run_test(
            "User Registration",
            "POST",
            "api/auth/register",
            expected_status,
            data={"email": email, "password": password},
            auth=False
        )
        if success and expected_status == 200 and 'token' in response:
            self.token = response['token']
            print(f"    Registered user: {email}")
            return True, response
        return success, response

    def test_login(self, email, password):
        """Test user login"""
        success, response = self.run_test(
            "User Login",
            "POST",
            "api/auth/login",
            200,
            data={"email": email, "password": password},
            auth=False
        )
        if success and 'token' in response:
            self.token = response['token']
            print(f"    Logged in user: {email}")
            return True, response
        return False, response

    def test_get_user_profile(self):
        """Test getting user profile"""
        return self.run_test("Get User Profile", "GET", "api/auth/me", 200)

    def test_list_dns_records(self):
        """Test listing DNS records"""
        return self.run_test("List DNS Records", "GET", "api/dns/records", 200)

    def test_create_dns_record(self, record_type, name, content):
        """Test creating a DNS record"""
        success, response = self.run_test(
            f"Create DNS Record ({record_type})",
            "POST",
            "api/dns/records",
            200,
            data={
                "record_type": record_type,
                "name": name,
                "content": content,
                "ttl": 1,
                "proxied": False
            }
        )
        if success and 'id' in response:
            self.created_records.append(response['id'])
            print(f"    Created record: {name}.ddns.land -> {content}")
        return success, response

    def test_update_dns_record(self, record_id, new_content):
        """Test updating a DNS record"""
        return self.run_test(
            "Update DNS Record",
            "PUT",
            f"api/dns/records/{record_id}",
            200,
            data={"content": new_content, "ttl": 1, "proxied": False}
        )

    def test_delete_dns_record(self, record_id):
        """Test deleting a DNS record"""
        success, response = self.run_test(
            "Delete DNS Record",
            "DELETE",
            f"api/dns/records/{record_id}",
            200
        )
        if success and record_id in self.created_records:
            self.created_records.remove(record_id)
        return success, response

    def test_free_plan_limit(self):
        """Test free plan record limit (should fail after 2 records)"""
        print(f"\n🔍 Testing Free Plan Limit (3rd record should fail)...")
        success, response = self.run_test(
            "Free Plan Limit Test",
            "POST",
            "api/dns/records",
            403,  # Should return 403 for limit exceeded
            data={
                "record_type": "A",
                "name": f"limit-test-{int(time.time())}",
                "content": "192.168.1.3",
                "ttl": 1,
                "proxied": False
            }
        )
        return success, response

    def test_admin_login(self, email, password):
        """Test admin user login and verify role"""
        success, response = self.run_test(
            "Admin Login",
            "POST",
            "api/auth/login",
            200,
            data={"email": email, "password": password},
            auth=False
        )
        if success and 'token' in response:
            self.token = response['token']
            user_data = response.get('user', {})
            if user_data.get('role') == 'admin':
                print(f"    Admin login successful: {email} (role: {user_data.get('role')})")
                return True, response
            else:
                print(f"    Login successful but role is not admin: {user_data.get('role')}")
                return False, response
        return False, response

    def test_admin_stats(self):
        """Test admin stats endpoint"""
        return self.run_test("Admin Stats", "GET", "api/admin/stats", 200)

    def test_admin_users_list(self):
        """Test admin users list endpoint"""
        return self.run_test("Admin Users List", "GET", "api/admin/users", 200)

    def test_admin_update_user_plan(self, user_id, plan):
        """Test admin updating user plan"""
        return self.run_test(
            f"Admin Update User Plan to {plan}",
            "PUT",
            f"api/admin/users/{user_id}/plan",
            200,
            data={"plan": plan}
        )

    def test_admin_delete_user(self, user_id):
        """Test admin deleting user"""
        return self.run_test(
            "Admin Delete User",
            "DELETE",
            f"api/admin/users/{user_id}",
            200
        )

    def test_non_admin_admin_access(self):
        """Test non-admin user accessing admin endpoints"""
        success1, _ = self.run_test("Non-admin Stats Access", "GET", "api/admin/stats", 403)
        success2, _ = self.run_test("Non-admin Users Access", "GET", "api/admin/users", 403)
        return success1 and success2, {}

    def test_gmail_only_registration(self):
        """Test Gmail-only registration policy"""
        # Test non-Gmail registration (should fail)
        success1, _ = self.test_register("test@yahoo.com", "password123", 400)
        success2, _ = self.test_register("test@outlook.com", "password123", 400)  
        success3, _ = self.test_register("test@example.com", "password123", 400)
        
        # Test Gmail registration (should succeed)
        timestamp = int(time.time())
        gmail_email = f"testuser{timestamp}@gmail.com"
        success4, response = self.test_register(gmail_email, "password123", 200)
        
        all_success = success1 and success2 and success3 and success4
        return all_success, response

    def cleanup_records(self):
        """Clean up created test records"""
        if self.created_records:
            print(f"\n🧹 Cleaning up {len(self.created_records)} test records...")
            for record_id in self.created_records.copy():
                success, _ = self.test_delete_dns_record(record_id)
                if success:
                    print(f"    Deleted record: {record_id}")
                else:
                    print(f"    Failed to delete record: {record_id}")

def main():
    print("🚀 Starting DDNS.LAND API Testing")
    print("=" * 50)
    
    tester = DDNSAPITester()
    timestamp = int(time.time())
    test_email = f"test_user_{timestamp}@example.com"
    test_password = "TestPass123!"

    # Test basic health
    tester.test_health()

    # Test authentication
    success, user_data = tester.test_register(test_email, test_password)
    if not success:
        print("❌ Registration failed, stopping tests")
        return 1

    # Test user profile
    tester.test_get_user_profile()

    # Test DNS record operations
    tester.test_list_dns_records()

    # Create first DNS record (A record)
    success, record1 = tester.test_create_dns_record("A", f"test-a-{timestamp}", "192.168.1.1")
    if not success:
        print("❌ Failed to create first DNS record")
        return 1

    # Create second DNS record (CNAME record)  
    success, record2 = tester.test_create_dns_record("CNAME", f"test-cname-{timestamp}", "example.com")
    if not success:
        print("❌ Failed to create second DNS record")
        return 1

    # Test free plan limit (3rd record should fail)
    tester.test_free_plan_limit()

    # Test record update
    if record1 and 'id' in record1:
        tester.test_update_dns_record(record1['id'], "192.168.1.100")

    # Test invalid auth
    tester.test_invalid_auth()

    # Test with different user login
    test_login_success, _ = tester.test_login(test_email, test_password)
    if test_login_success:
        print("    Login with existing user successful")

    # Clean up test records
    tester.cleanup_records()

    # Print final results
    print("\n" + "=" * 50)
    print(f"📊 Test Summary:")
    print(f"   Total Tests: {tester.tests_run}")
    print(f"   Passed: {tester.tests_passed}")
    print(f"   Failed: {tester.tests_run - tester.tests_passed}")
    print(f"   Success Rate: {(tester.tests_passed/tester.tests_run*100):.1f}%")
    
    # Log failed tests
    failed_tests = [t for t in tester.test_results if not t['success']]
    if failed_tests:
        print(f"\n❌ Failed Tests:")
        for test in failed_tests:
            print(f"   - {test['test']}: {test['error']}")
    
    return 0 if tester.tests_passed == tester.tests_run else 1

if __name__ == "__main__":
    sys.exit(main())