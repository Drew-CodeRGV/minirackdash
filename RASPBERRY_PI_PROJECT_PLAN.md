# MiniRack Dashboard - Raspberry Pi 5 Standalone Image Project

## Project Overview
Create a custom Raspberry Pi 5 image with the MiniRack Dashboard pre-installed that:
- Boots ready-to-use from SD card
- Automatically emails IP address to drew@drewlentz.com
- Runs dashboard on boot
- Includes all dependencies pre-installed
- Zero configuration required

## Technical Approach

### Option 1: Custom Image Creation (Recommended)
1. **Base Image**: Start with Raspberry Pi OS Lite (64-bit)
2. **Pre-installation**: Install all dependencies and dashboard
3. **Boot Scripts**: Auto-start dashboard and email IP
4. **Image Creation**: Create distributable .img file

### Option 2: First-Boot Script (Alternative)
1. **Base Image**: Standard Raspberry Pi OS
2. **Boot Script**: Install everything on first boot
3. **Simpler**: But requires internet on first boot

## Implementation Steps

### Phase 1: Repository Setup
- [x] Fork repository for Pi version
- [ ] Create Pi-specific branch
- [ ] Adapt dashboard for Pi environment

### Phase 2: Installation Scripts
- [ ] Create Pi-optimized installation script
- [ ] Email notification system
- [ ] Auto-start configuration
- [ ] Network detection and reporting

### Phase 3: Image Creation
- [ ] Base image preparation
- [ ] Dependency pre-installation
- [ ] Service configuration
- [ ] Image compression and distribution

### Phase 4: Testing & Distribution
- [ ] Test on Pi 5 hardware
- [ ] Create documentation
- [ ] Distribution method (GitHub releases)

## Technical Requirements

### Hardware Support
- Raspberry Pi 5 (primary target)
- Raspberry Pi 4 (compatibility)
- Minimum 8GB SD card
- Network connectivity (WiFi or Ethernet)

### Software Stack
- Raspberry Pi OS Lite (64-bit)
- Python 3.11+
- Nginx
- Systemd services
- Email client (msmtp or similar)

### Dashboard Adaptations
- Pi-optimized performance settings
- Local network discovery
- Hardware-specific optimizations
- Reduced resource usage

## Email Notification System
- SMTP configuration for notifications
- IP address detection (both WiFi and Ethernet)
- Boot completion notification
- Error reporting capability

## File Structure
```
raspberry-pi/
├── scripts/
│   ├── install-dashboard.sh
│   ├── setup-email.sh
│   ├── boot-notification.sh
│   └── create-image.sh
├── config/
│   ├── systemd/
│   ├── nginx/
│   └── email/
├── dashboard/
│   ├── pi-optimized files
│   └── configuration
└── docs/
    ├── README.md
    ├── INSTALLATION.md
    └── TROUBLESHOOTING.md
```

## Next Steps
1. Create repository fork
2. Develop Pi-specific installation scripts
3. Test on actual Pi 5 hardware
4. Create image building process
5. Document and distribute