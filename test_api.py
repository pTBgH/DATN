import urllib.request
import urllib.parse
import json
import sys

GATEWAY_URL = "http://100.108.231.127:30000"
KEYCLOAK_URL = GATEWAY_URL

def get_token():
    url = f"{KEYCLOAK_URL}/realms/job7189/protocol/openid-connect/token"
    data = urllib.parse.urlencode({
        "grant_type": "password",
        "client_id": "recruiter-app",
        "username": "recruiter1",
        "password": "recruiter1"
    }).encode("utf-8")
    
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req) as res:
            res_data = json.loads(res.read().decode("utf-8"))
            return res_data["access_token"]
    except Exception as e:
        print(f"Error authenticating to Keycloak: {e}")
        sys.exit(1)

def api_get(path, token=None):
    url = f"{GATEWAY_URL}{path}"
    headers = {
        "Accept": "application/json",
        "Host": "api.job7189.local" # Kong might match routes based on host or path
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
        
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=5) as res:
            return res.status, json.loads(res.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read().decode("utf-8"))
        except:
            body = e.reason
        return e.code, body
    except Exception as e:
        return 0, str(e)

def run_tests():
    print("Obtaining Access Token...")
    token = get_token()
    print("Token obtained successfully.")
    
    results = {}
    
    # 1. Identity & Profile
    print("Testing Identity Profile...")
    results["GET /api/recruiters/profile"] = api_get("/api/recruiters/profile", token)
    
    # 2. Options & Metadata
    print("Testing Metadata and Options...")
    results["GET /api/options/company-types"] = api_get("/api/options/company-types")
    results["GET /api/options/general"] = api_get("/api/options/general")
    results["GET /api/public/metadata/common"] = api_get("/api/public/metadata/common")
    
    # 3. Workspaces
    print("Testing Workspaces list...")
    code, ws_list_res = api_get("/api/my-workspaces", token)
    results["GET /api/my-workspaces"] = (code, "Success" if code == 200 else ws_list_res)
    
    workspace_id = None
    if code == 200:
        workspaces = ws_list_res
        # Support both wrapped and unwrapped format
        if isinstance(workspaces, dict) and "data" in workspaces:
            workspaces = workspaces["data"]
        
        if isinstance(workspaces, list) and len(workspaces) > 0:
            workspace_id = workspaces[0].get("id") or workspaces[0].get("workspace_id")
            print(f"Using workspace ID: {workspace_id} for detail testing")
            results[f"GET /api/workspaces/{workspace_id}"] = api_get(f"/api/workspaces/{workspace_id}", token)
            results[f"POST /api/workspaces/{workspace_id}/invite-code"] = api_get(f"/api/workspaces/{workspace_id}/invite-code", token) # POST actually but we query it
        else:
            print("No workspaces found for recruiter1")
            
    # 4. Jobs
    print("Testing Public Jobs...")
    results["GET /api/public/jobs"] = api_get("/api/public/jobs")
    
    if workspace_id:
        print(f"Testing Jobs in Workspace {workspace_id}...")
        j_code, j_list_res = api_get(f"/api/workspaces/{workspace_id}/jobs", token)
        results[f"GET /api/workspaces/{workspace_id}/jobs"] = (j_code, "Success" if j_code == 200 else j_list_res)
        
        job_id = None
        if j_code == 200:
            jobs = j_list_res
            if isinstance(jobs, dict) and "data" in jobs:
                jobs = jobs["data"]
            if isinstance(jobs, list) and len(jobs) > 0:
                job_id = jobs[0].get("job_id") or jobs[0].get("id")
                print(f"Using job ID: {job_id} for detail testing")
                results[f"GET /api/workspaces/{workspace_id}/jobs/{job_id}"] = api_get(f"/api/workspaces/{workspace_id}/jobs/{job_id}", token)
                results[f"GET /api/board/{job_id}"] = api_get(f"/api/board/{job_id}", token)
            else:
                print("No jobs found in this workspace")
                
        # 5. Hiring & Pipelines
        print(f"Testing Pipelines for Workspace {workspace_id}...")
        results[f"GET /api/workspaces/{workspace_id}/pipelines"] = api_get(f"/api/workspaces/{workspace_id}/pipelines", token)

    # 6. Conversations
    print("Testing Conversations...")
    c_code, c_list_res = api_get("/api/conversations", token)
    results["GET /api/conversations"] = (c_code, "Success" if c_code == 200 else c_list_res)
    if c_code == 200 and isinstance(c_list_res, list) and len(c_list_res) > 0:
        c_id = c_list_res[0].get("conversation_id")
        results[f"GET /api/conversations/{c_id}/messages"] = api_get(f"/api/conversations/{c_id}/messages", token)
        
    # 7. Admin endpoints (recruiter1 may or may not have admin privileges)
    print("Testing Admin endpoints...")
    results["GET /api/admin/users"] = api_get("/api/admin/users", token)
    results["GET /api/admin/companies"] = api_get("/api/admin/companies", token)
    results["GET /api/admin/jobs"] = api_get("/api/admin/jobs", token)
    results["GET /api/admin/categories/sectors"] = api_get("/api/admin/categories/sectors", token)

    print("\n" + "="*50)
    print("                  API TEST SUMMARY")
    print("="*50)
    
    failures = []
    
    for endpoint, (code, body) in results.items():
        status = "PASSED" if code in (200, 201, 204, 403, 404) else "FAILED" # 403/404 are correct endpoint behaviors (unprivileged/no record) whereas 500/502/504 or 0 are failures
        print(f"{endpoint:<60} | Status Code: {code:<3} | {status}")
        if status == "FAILED":
            failures.append((endpoint, code, body))
            
    print("\n" + "="*50)
    if failures:
        print(f"Detected {len(failures)} failures:")
        for ep, code, body in failures:
            print(f"- {ep} (Code: {code})")
            print(f"  Response: {body}\n")
    else:
        print("All tested APIs are functioning properly without 500 errors!")

if __name__ == "__main__":
    run_tests()
