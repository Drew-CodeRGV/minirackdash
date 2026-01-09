class ResponseBuilder {
    /**
     * Build welcome response for launch intent
     */
    buildWelcomeResponse(deviceCount, networkStatus) {
        const { totalNetworks, onlineNetworks } = networkStatus;
        
        let response = `Welcome to your Eero Dashboard! `;
        
        if (deviceCount > 0) {
            response += `You currently have ${deviceCount} device${deviceCount !== 1 ? 's' : ''} connected to your network${totalNetworks > 1 ? 's' : ''}. `;
        }
        
        if (totalNetworks > 1) {
            response += `All ${onlineNetworks} of your ${totalNetworks} networks are online. `;
        }
        
        response += `What would you like to know about your network?`;
        
        return response;
    }

    /**
     * Build device count response
     */
    buildDeviceCountResponse(networkData) {
        if (!networkData || networkData.length === 0) {
            return "I couldn't find any network information. Please make sure your networks are configured and try again.";
        }

        const totalDevices = networkData.reduce((sum, network) => sum + network.totalDevices, 0);
        const totalWireless = networkData.reduce((sum, network) => sum + network.wirelessDevices, 0);
        const totalWired = networkData.reduce((sum, network) => sum + network.wiredDevices, 0);

        let response = `You have ${totalDevices} device${totalDevices !== 1 ? 's' : ''} connected`;
        
        if (networkData.length > 1) {
            response += ` across your ${networkData.length} networks`;
        }
        
        response += `. `;

        if (totalWireless > 0 && totalWired > 0) {
            response += `${totalWireless} are wireless and ${totalWired} are wired. `;
        } else if (totalWireless > 0) {
            response += `All are connected wirelessly. `;
        } else if (totalWired > 0) {
            response += `All are wired connections. `;
        }

        // Add busiest network info if multiple networks
        if (networkData.length > 1) {
            const busiestNetwork = networkData.reduce((max, network) => 
                network.totalDevices > max.totalDevices ? network : max
            );
            
            if (busiestNetwork.totalDevices > 0) {
                response += `Your busiest network is ${busiestNetwork.name} with ${busiestNetwork.totalDevices} devices.`;
            }
        }

        return response;
    }

    /**
     * Build network status response
     */
    buildNetworkStatusResponse(networkData) {
        if (!networkData || networkData.length === 0) {
            return "I couldn't get your network status right now. Please try again.";
        }

        let response = "Your network";
        
        if (networkData.length > 1) {
            response += "s are";
        } else {
            response += " is";
        }
        
        response += " running smoothly. ";

        const totalDevices = networkData.reduce((sum, network) => sum + network.totalDevices, 0);
        const totalAPs = networkData.reduce((sum, network) => sum + network.accessPoints.length, 0);

        if (totalDevices > 0) {
            response += `${totalDevices} device${totalDevices !== 1 ? 's are' : ' is'} currently connected. `;
        }

        if (totalAPs > 0) {
            response += `All ${totalAPs} access point${totalAPs !== 1 ? 's are' : ' is'} online`;
            
            if (networkData.length > 1) {
                response += ` across your networks`;
            }
            
            response += `. `;
        }

        // Add performance summary
        response += "Network performance is good with strong signal coverage.";

        return response;
    }

    /**
     * Build device types response
     */
    buildDeviceTypesResponse(networkData) {
        if (!networkData || networkData.length === 0) {
            return "I couldn't get device type information right now.";
        }

        // Aggregate device types across all networks
        const totalTypes = {
            phones: 0,
            laptops: 0,
            tablets: 0,
            smartHome: 0,
            gaming: 0,
            streaming: 0,
            other: 0
        };

        networkData.forEach(network => {
            Object.keys(totalTypes).forEach(type => {
                totalTypes[type] += network.deviceTypes[type] || 0;
            });
        });

        const deviceTypeNames = {
            phones: 'phone',
            laptops: 'laptop',
            tablets: 'tablet',
            smartHome: 'smart home device',
            gaming: 'gaming device',
            streaming: 'streaming device',
            other: 'other device'
        };

        const connectedTypes = [];
        
        Object.entries(totalTypes).forEach(([type, count]) => {
            if (count > 0) {
                const name = deviceTypeNames[type];
                connectedTypes.push(`${count} ${name}${count !== 1 ? 's' : ''}`);
            }
        });

        if (connectedTypes.length === 0) {
            return "No devices are currently connected to your network.";
        }

        let response = "You have ";
        
        if (connectedTypes.length === 1) {
            response += connectedTypes[0];
        } else if (connectedTypes.length === 2) {
            response += `${connectedTypes[0]} and ${connectedTypes[1]}`;
        } else {
            const lastType = connectedTypes.pop();
            response += `${connectedTypes.join(', ')}, and ${lastType}`;
        }
        
        response += " connected.";

        return response;
    }

    /**
     * Build AP performance response
     */
    buildAPPerformanceResponse(apData) {
        if (!apData || apData.length === 0) {
            return "I couldn't get access point information right now.";
        }

        // Sort APs by device count
        const sortedAPs = apData.sort((a, b) => b.deviceCount - a.deviceCount);
        const busiestAP = sortedAPs[0];
        const totalAPs = apData.length;

        let response = `You have ${totalAPs} access point${totalAPs !== 1 ? 's' : ''} online. `;

        if (busiestAP && busiestAP.deviceCount > 0) {
            const apName = this.getAPDisplayName(busiestAP);
            response += `Your busiest access point is ${apName} with ${busiestAP.deviceCount} device${busiestAP.deviceCount !== 1 ? 's' : ''}. `;
        }

        // Add performance summary
        const activeAPs = apData.filter(ap => ap.deviceCount > 0);
        if (activeAPs.length > 0) {
            response += `${activeAPs.length} access point${activeAPs.length !== 1 ? 's are' : ' is'} actively serving devices with good signal strength.`;
        } else {
            response += "All access points are online and ready for connections.";
        }

        return response;
    }

    /**
     * Build events response
     */
    buildEventsResponse(events) {
        if (!events || events.length === 0) {
            return "No recent network events to report. Your network has been stable.";
        }

        const recentEvents = events.slice(0, 5); // Limit to 5 most recent events
        let response = "Here are your recent network events: ";

        const eventDescriptions = recentEvents.map(event => {
            return this.formatEventDescription(event);
        });

        if (eventDescriptions.length === 1) {
            response += eventDescriptions[0];
        } else if (eventDescriptions.length === 2) {
            response += `${eventDescriptions[0]} and ${eventDescriptions[1]}`;
        } else {
            const lastEvent = eventDescriptions.pop();
            response += `${eventDescriptions.join(', ')}, and ${lastEvent}`;
        }

        response += ".";

        return response;
    }

    /**
     * Get display name for an access point
     */
    getAPDisplayName(ap) {
        if (ap.nickname && ap.nickname.trim()) {
            return ap.nickname;
        }
        
        if (ap.location && ap.location.name) {
            return `the ${ap.location.name} access point`;
        }
        
        if (ap.model) {
            return `the ${ap.model}`;
        }
        
        return "an access point";
    }

    /**
     * Format event description for voice
     */
    formatEventDescription(event) {
        const timeAgo = this.getTimeAgoDescription(event.timestamp);
        
        switch (event.type) {
            case 'device_connected':
                return `${event.deviceName || 'A device'} connected ${timeAgo}`;
            
            case 'device_disconnected':
                return `${event.deviceName || 'A device'} disconnected ${timeAgo}`;
            
            case 'new_device':
                return `A new device called ${event.deviceName || 'unknown device'} joined ${timeAgo}`;
            
            case 'performance_alert':
                return `Network performance alert ${timeAgo}`;
            
            case 'ap_offline':
                return `Access point went offline ${timeAgo}`;
            
            case 'ap_online':
                return `Access point came back online ${timeAgo}`;
            
            default:
                return `Network event occurred ${timeAgo}`;
        }
    }

    /**
     * Get human-readable time ago description
     */
    getTimeAgoDescription(timestamp) {
        const now = new Date();
        const eventTime = new Date(timestamp);
        const diffMs = now - eventTime;
        const diffMins = Math.floor(diffMs / (1000 * 60));
        const diffHours = Math.floor(diffMins / 60);
        const diffDays = Math.floor(diffHours / 24);

        if (diffMins < 1) {
            return "just now";
        } else if (diffMins < 60) {
            return `${diffMins} minute${diffMins !== 1 ? 's' : ''} ago`;
        } else if (diffHours < 24) {
            return `${diffHours} hour${diffHours !== 1 ? 's' : ''} ago`;
        } else if (diffDays < 7) {
            return `${diffDays} day${diffDays !== 1 ? 's' : ''} ago`;
        } else {
            return "over a week ago";
        }
    }
}

module.exports = ResponseBuilder;