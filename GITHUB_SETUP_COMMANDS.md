# GitHub Repository Setup Commands

## Step 1: Create GitHub Repository
1. Go to https://github.com/new
2. Repository name: `eero-event-dashboard`
3. Description: `Comprehensive mobile-responsive dashboard for monitoring multiple Eero networks with real-time analytics and data export`
4. Set to **Public**
5. **DO NOT** check "Add a README file" (we have our own)
6. **DO NOT** check "Add .gitignore" (we have our own)
7. **DO NOT** check "Choose a license" (we have our own)
8. Click **"Create repository"**

## Step 2: Push to GitHub
Run these commands in your terminal:

```bash
# Navigate to the new repository directory
cd ../eero-event-dashboard

# Initialize git repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Eero Event Dashboard v6.8.0

Features:
- Full-height per-network information display
- Clickable Eero Insight links for all network IDs
- CSV export with comprehensive network and device data
- Real-time multi-network monitoring (up to 6 networks)
- Mobile-responsive design with touch optimization
- Production Eero API authentication
- Device type detection (iOS, Android, Windows, Amazon, Gaming, Streaming)
- Frequency analysis (2.4GHz, 5GHz, 6GHz) per network
- Time range selection (1h to 1 week)
- Secure token storage per network
- AWS Lightsail deployment ready
- Local macOS development support

This is a complete, standalone repository with all working features."

# Add remote repository (replace with your actual GitHub username if different)
git remote add origin https://github.com/Drew-CodeRGV/eero-event-dashboard.git

# Set main branch
git branch -M main

# Push to GitHub
git push -u origin main
```

## Step 3: Test Local Installation
After pushing to GitHub, test by cloning and running:

```bash
# Clone the new repository to test
cd ~/Desktop
git clone https://github.com/Drew-CodeRGV/eero-event-dashboard.git
cd eero-event-dashboard

# Run the dashboard locally
python3 dashboard_simple_local.py

# Access at http://localhost:3000
```

## Step 4: Verify Repository
Your GitHub repository should show:
- ✅ 14 files including README.md, LICENSE, .gitignore
- ✅ Professional README with badges and comprehensive documentation
- ✅ All dashboard files (dashboard_simple_local.py, deploy/, etc.)
- ✅ Setup and deployment scripts
- ✅ Clean commit history starting fresh

## Repository URL
Once created: https://github.com/Drew-CodeRGV/eero-event-dashboard

## Quick Test Commands
```bash
# Test the main local dashboard
python3 dashboard_simple_local.py

# Test CSV export (after dashboard is running)
curl -s http://localhost:3000/api/export/csv | head -5

# Test network stats
curl -s http://localhost:3000/api/network-stats | python3 -m json.tool
```