# 🚀 Local UI Access Guide

## ✅ Status: Both Frontends Running!

```
fe-candidate   ✅ Up   http://localhost:3001
fe-recruiter   ✅ Up   http://localhost:3002
```

---

## 🌐 Access the UI

### **Candidate Portal**
```
URL: http://localhost:3001
Features:
  • Job Listing & Search
  • User Login/Register
  • CV Upload & Management
  • Job Applications
  • Profile Page
```

### **Recruiter Portal**
```
URL: http://localhost:3002
Features:
  • Dashboard with Stats
  • Active Jobs Management
  • Candidate Applications Tracking
  • Hiring Board Pipeline
  • Team & Workspace
```

---

## 🛠️ Docker Commands

### View Logs (Real-time)
```bash
# Candidate logs
docker-compose -f docker-compose.frontends.yml logs -f fe-candidate

# Recruiter logs
docker-compose -f docker-compose.frontends.yml logs fe-recruiter

# All logs
docker-compose -f docker-compose.frontends.yml logs -f
```

### Stop Services
```bash
docker-compose -f docker-compose.frontends.yml down
```

### Restart Services
```bash
docker-compose -f docker-compose.frontends.yml restart
```

### Stop & Clean (Remove volumes)
```bash
docker-compose -f docker-compose.frontends.yml down -v
```

---

## 📱 UI Preview

### **Candidate Portal** - Main Features

```
┌─────────────────────────────────────────────────────────┐
│ Job Portal Candidate                    [Login] [Register]│
├─────────────────────────────────────────────────────────┤
│                                                           │
│  🔍 Search Jobs                    💙 ❤️ Favorites      │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Senior React │  │ Node.js Dev  │  │ DevOps Eng.  │   │
│  │ Developer    │  │              │  │              │   │
│  │ 🗺️ Location │  │ 🗺️ Location │  │ 🗺️ Location │   │
│  │ 💰 Salary    │  │ 💰 Salary    │  │ 💰 Salary    │   │
│  │ [Apply]      │  │ [Apply]      │  │ [Apply]      │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ More Jobs...                                          │
└─────────────────────────────────────────────────────────┘
```

### **Recruiter Portal** - Dashboard

```
┌─────────────────────────────────────────────────────────┐
│ 📊 Recruiter Dashboard              👤 Admin [Logout]   │
├──────────────────────────────────────────────────────────┤
│ ☰ Menu                                                   │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  ┌─────────────────┐  ┌─────────────────┐               │
│  │ 📌 Active Jobs  │  │ 👥 Pending      │               │
│  │ 12              │  │ Candidates      │               │
│  │ Jobs            │  │ 45              │               │
│  └─────────────────┘  └─────────────────┘               │
│                                                           │
│  ┌─────────────────┐  ┌─────────────────┐               │
│  │ 📅 Interviews   │  │ ✅ Closed       │               │
│  │ 8 Scheduled     │  │ 23 Positions    │               │
│  └─────────────────┘  └─────────────────┘               │
│                                                           │
│  🔗 Quick Links:  [Jobs] [Candidates] [Hiring Board]    │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

---

## 🧪 Testing the UI

### 1. **Test Candidate Portal**
```bash
# Open in browser
open http://localhost:3001
# or
xdg-open http://localhost:3001  # Linux
```

**Actions to try**:
- [ ] View home page (should show job listings)
- [ ] Click on a job (shows job details)
- [ ] Try login page (shows form)
- [ ] Try register page (shows form)
- [ ] Click profile (shows CV management)

### 2. **Test Recruiter Portal**
```bash
# Open in browser
open http://localhost:3002
# or
xdg-open http://localhost:3002  # Linux
```

**Actions to try**:
- [ ] View dashboard (shows stats cards)
- [ ] Check sidebar navigation
- [ ] View stats (active jobs, pending candidates, etc.)
- [ ] Try navigation links

---

## 🔧 Troubleshooting

### Port Already in Use
If ports 3001/3002 are already in use:
```bash
# Kill process on port
lsof -ti:3001 | xargs kill -9
lsof -ti:3002 | xargs kill -9

# Or use different ports - edit docker-compose.frontends.yml
```

### Container Won't Start
```bash
# Check logs
docker-compose -f docker-compose.frontends.yml logs fe-candidate

# Rebuild
docker-compose -f docker-compose.frontends.yml up --build --no-cache
```

### Can't Access UI
```bash
# Check if containers are running
docker ps

# Check network
docker network ls
docker network inspect doan2_job7189

# Test connectivity
curl -v http://localhost:3001
```

---

## 🔐 Login Credentials (Mock)

Since backend is not running, you'll see:
- Login form is ready
- Submit will show API error (expected - backend offline)
- Forms are fully styled and interactive

**To test with backend**:
1. Make sure backend services are running on Kong (port 8000)
2. Check `NEXT_PUBLIC_API_BASE_URL` in docker-compose.yml
3. Responses will come from backend APIs

---

## 📊 Monitor Resources

```bash
# Check container resource usage
docker stats

# Check disk space
df -h

# Check memory
free -h
```

---

## 🎨 UI Customization

Both portals are fully styled with:
- **Ant Design 5** - Professional components
- **Tailwind CSS** - Custom styling
- **Framer Motion** - Smooth animations
- **Responsive Design** - Works on all screen sizes

You can customize colors in:
- `tailwind.config.js` - Color scheme
- `src/app/page.css` - Component styling
- Ant Design theme in `src/app/layout.tsx`

---

## 📚 More Information

See documentation:
- [FRONTEND_README.md](mdfile/FRONTEND_README.md) - Feature guide
- [FRONTEND_ARCHITECTURE.md](mdfile/FRONTEND_ARCHITECTURE.md) - System design
- [FRONTEND_API_GUIDE.md](mdfile/FRONTEND_API_GUIDE.md) - API integration

---

## ⏹️ Stop Services

When done:
```bash
docker-compose -f docker-compose.frontends.yml down
```

---

**Status**: ✅ Both frontends running and accessible!  
**Last Updated**: March 31, 2026  
**Environment**: Local Docker
