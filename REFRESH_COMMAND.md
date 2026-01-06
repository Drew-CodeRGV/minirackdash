# Complete Dashboard Refresh Command

Run this single command via SSH to completely fix the dashboard:

```bash
curl -s https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/complete_refresh.sh | sudo bash
```

This command will:
- ✅ Stop all services safely
- ✅ Download fresh files from GitHub (v6.5.0-complete)
- ✅ Verify file integrity and completeness
- ✅ Fix all permissions and configurations
- ✅ Restart services properly
- ✅ Test full functionality including π admin menu
- ✅ Ensure charts, time ranges, and all features work

The script is bulletproof and will exit with clear error messages if anything fails.

## What's Fixed in v6.5.0-complete:
- π Admin menu fully functional with all click handlers
- Complete HTML file loading (verified 20KB+ size)
- All JavaScript functions properly defined
- Time range selector working correctly
- Network ID admin panel with Eero Insight links
- Dashboard update functionality
- API reauthorization flow
- Device monitoring with wired/wireless detection
- All charts displaying whole numbers
- Proper error handling and logging

After running this command, you should have a fully functional dashboard with working admin panel accessible via the π button in the bottom-right corner.