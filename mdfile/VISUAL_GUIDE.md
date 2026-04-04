# 🎨 What You Should See - Visual Guide

## Candidate Portal (http://localhost:3001)

### When You First Load

```
┌─────────────────────────────────────────────────────────────────────┐
│ 💼 Job Portal              [Login]  [Register]                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│     Find Your Next Opportunity                                      │
│     Browse thousands of job listings from top companies            │
│                                                                      │
│    [🔍 Search jobs by title...                                  ✕] │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│    Showing 12 jobs                                                 │
│                                                                      │
│   ┌─────────────────────┐  ┌─────────────────────┐                │
│   │ Senior React Dev    │  │ Node.js Developer   │                │
│   │ ❤️                 │  │ ❤️                 │                │
│   │ Company ABC         │  │ Company XYZ         │                │
│   │ 📍 Ho Chi Minh      │  │ 📍 Hanoi            │                │
│   │ 💰 30M - 50M VNĐ    │  │ 💰 25M - 40M VNĐ    │                │
│   │ [💼 Full-time]      │  │ [💼 Full-time]      │                │
│   │ Seeking experienced │  │ Build scalable      │                │
│   │ React developer...  │  │ backend systems...  │                │
│   │ [View & Apply]      │  │ [Login to Apply]    │                │
│   └─────────────────────┘  └─────────────────────┘                │
│                                                                      │
│   ┌─────────────────────┐  ┌─────────────────────┐                │
│   │ More jobs...        │  │ More cards...       │                │
│   └─────────────────────┘  └─────────────────────┘                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### ✅ What You Should See

- [x] Header with "💼 Job Portal" title
- [x] Login and Register buttons (top right)
- [x] "Find Your Next Opportunity" heading
- [x] Search bar with placeholder text
- [x] Job cards in a grid layout (3 columns on desktop)
- [x] Each card has:
  - Job title
  - Company name 
  - Location with 📍 icon
  - Salary range with 💰 icon
  - Job type tag (Full-time/Part-time)
  - Description (2-line preview)
  - Heart icon to favorite
  - Apply button
- [x] Smooth animations when scrolling
- [x] Loading spinner while fetching

### ✅ What You Should NOT See

- [x] No "Not Found" or 404 errors
- [x] No forced login screen
- [x] No console errors (`F12` → Console should be green)
- [x] No "ReferenceError" messages

---

## Recruiter Portal (http://localhost:3002)

### When You First Load (Before Login)

```
┌──────────────────────────────────────────────────────────────┐
│ Logo                          [Equal, Not Very Clear Auth]    │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Loading...  [Spinner]                                      │
│                                                               │
│  (If not logged in, redirects to login page)                │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### After Login

```
┌──────────────────────────────────────────────────────────────┐
│ ☰ [collapsed]    Recruiter Hub           user@email.com 🚪 │
├─────────────────────────┬──────────────────────────────────┤
│ 📊 Dashboard            │                                    │
│ 📋 Công Việc            │ Bảng Điều Khiển                 │
│ 👥 Ứng Viên             │                                    │
│ 📇 Bảng Tuyển           │ Workspace: Tech Company          │
│                         │                                    │
│                         │ ┌──────────────┐ ┌──────────────┐ │
│                         │ │ 📌 Active    │ │ 👥 Pending   │ │
│                         │ │ Jobs         │ │ Candidates   │ │
│                         │ │ 12           │ │ 48           │ │
│                         │ └──────────────┘ └──────────────┘ │
│                         │                                    │
│                         │ ┌──────────────┐ ┌──────────────┐ │
│                         │ │ 📅 Interviews│ │ ✅ Closed    │ │
│                         │ │ 8 Scheduled  │ │ 23 Positions │ │
│                         │ └──────────────┘ └──────────────┘ │
│                         │                                    │
│                         │ [Create New Job]                   │
│                         │                                    │
└─────────────────────────┴──────────────────────────────────┘
```

### ✅ What You Should See

- [x] Sidebar with dark background
- [x] Menu items: Dashboard, Jobs, Candidates, Hiring Board
- [x] Header with logo and user email
- [x] Logout button (🚪)
- [x] Dashboard content with:
  - 4 stat cards (colored backgrounds)
  - Stats: Active Jobs, Pending Candidates, Interviews, Closed
  - "Create New Job" button
- [x] Hamburger menu to collapse/expand sidebar
- [x] Smooth animations

### ✅ What You Should NOT See

- [x] No "location is not defined" errors
- [x] No 404 errors
- [x] No blank white page
- [x] No routing issues

---

## Error States

### ❌ If You See This (BEFORE FIX)

```
"ReferenceError: location is not defined"
at /app/.next/server/chunks/279.js:39:12488
```

**FIX**: ✅ APPLIED - Move router.push() to useEffect

---

### ❌ If You See This (BEFORE FIX)

```
404 Not Found
```

**FIX**: ✅ APPLIED - Fix routing in recruiter page

---

### ❌ If Jobs Don't Load

**Check**:
1. Browser console (F12 → Console tab)
2. Look for: `[API] Request: GET http://localhost:8000/jobs`
3. If you see error:
   ```
   [API] Network Error - Backend at http://localhost:8000 may be unreachable
   ```
   → Backend is not running

**Solution**:
```bash
# Test backend manually
curl http://localhost:8000/health
curl http://localhost:8000/jobs

# If fails, start backend services
# (Depends on your setup)
```

---

## Console Output

### When Everything Works ✅

Open DevTools (F12 → Console) and you should see:

```javascript
[API Client] Initializing with baseURL: http://localhost:8000
[API Client] Environment: development
[API Client] Keycloak URL: http://localhost:8080

[API] Request: GET http://localhost:8000/jobs {hasToken: false}
[Home] Loading jobs with keyword: undefined
[API] Response: 200 http://localhost:8000/jobs {dataSize: 1234}
[Home] Jobs loaded: 12
```

### If Backend is Down ❌

You'll see:

```javascript
[API] Request: GET http://localhost:8000/jobs {hasToken: false}
[API] Network Error - Backend at http://localhost:8000 may be unreachable
Error: connect ECONNREFUSED 127.0.0.1:8000
```

---

## Animation & Responsiveness

### Desktop (≥1024px)
- Job cards: 3 columns
- Full sidebar visible
- All text visible

### Tablet (600px - 1023px)
- Job cards: 2 columns
- Collapsible sidebar
- Responsive search bar

### Mobile (<600px)
- Job cards: 1 column (stack vertically)
- Hamburger menu for navigation
- Touch-friendly buttons
- Optimized spacing

---

## Interaction Examples

### Example 1: Search for a Job

```
User clicks search bar:
┌─────────────────────────┐
│🔍 Search jobs by title...│
└─────────────────────────┘

User types "React":
┌──────────────────────────────────┐
│🔍 React                       ✕  │
└──────────────────────────────────┘

Results update instantly:
┌────────────────────────┐
│ React Developer        │  ← Loaded!
│ React Engineer         │  ← Loaded!
│ React Specialist       │  ← Loaded!
└────────────────────────┘
```

### Example 2: View Job Details

```
User clicks job card:

Before:          After:
Job Grid    →    Job Detail
- React         Title: React Dev
- Node.js       Company: ABC
- Python        Location: HCMC
                Salary: 50M VNĐ
                [Apply Button]
```

### Example 3: Favorite a Job

```
User clicks heart icon:

Before:  ❤️ (heart outline)
         Click
After:   ❤️ (filled red heart)
         Click again
         ❤️ (outline again)
```

---

## Performance Indicators

### Page Load Time

- **Target**: < 3 seconds
- **Acceptable**: < 5 seconds
- **Error**: > 5 seconds

### API Response Time

- **GET /jobs**: < 500ms
- **GET /health**: < 100ms
- **POST /login**: < 1000ms

### UI Responsiveness

- **Animations**: Smooth (60fps)
- **Search**: Real-time (< 200ms)
- **Click response**: < 100ms

---

## Browser Compatibility

### Tested & Supported
- ✅ Chrome 90+
- ✅ Firefox 85+
- ✅ Safari 14+
- ✅ Edge 90+

### Mobile Browsers
- ✅ iOS Safari 14+
- ✅ Chrome Mobile
- ✅ Firefox Mobile

---

## Accessibility Features

### Built-in
- [x] Keyboard navigation (Tab, Enter)
- [x] Color contrast (WCAG AA)
- [x] Screen reader support (Ant Design)
- [x] Focus indicators
- [x] Semantic HTML

### Test with
- `Tab` + `Shift+Tab` for navigation
- `Enter` to activate buttons
- `Space` to toggle checkboxes
- `Escape` to close modals

---

## Success Checklist

- [ ] http://localhost:3001 loads job listings
- [ ] http://localhost:3002 shows login/dashboard
- [ ] Browser console shows API logs (no errors)
- [ ] Job cards display with proper styling
- [ ] Search works instantly
- [ ] Heart/favorite button works
- [ ] Login button is clickable
- [ ] Animations are smooth
- [ ] Responsive on mobile

---

## Still Having Issues?

### Check These in Order

1. **Container running?**
   ```bash
   docker-compose -f docker-compose.frontends.yml ps
   ```

2. **Ports available?**
   ```bash
   lsof -i :3001
   lsof -i :3002
   ```

3. **Backend running?**
   ```bash
   curl http://localhost:8000/health
   ```

4. **Logs clean?**
   ```bash
   docker logs fe-candidate
   docker logs fe-recruiter
   ```

5. **Console errors?**
   Open http://localhost:3001 → F12 → Console

---

**Now open your browser and test!** 🚀

👉 **http://localhost:3001** (Candidate)  
👉 **http://localhost:3002** (Recruiter)
