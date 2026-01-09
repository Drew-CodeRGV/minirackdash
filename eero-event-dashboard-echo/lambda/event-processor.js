const moment = require('moment');

class EventProcessor {
    constructor(dynamodb) {
        this.dynamodb = dynamodb;
        this.tableName = process.env.DYNAMODB_TABLE || 'eero-events';
    }

    /**
     * Get recent network events
     */
    async getRecentEvents(hours = 24) {
        try {
            const cutoffTime = moment().subtract(hours, 'hours').toISOString();
            
            const params = {
                TableName: this.tableName,
                FilterExpression: '#timestamp > :cutoff',
                ExpressionAttributeNames: {
                    '#timestamp': 'timestamp'
                },
                ExpressionAttributeValues: {
                    ':cutoff': cutoffTime
                },
                ScanIndexForward: false, // Most recent first
                Limit: 50
            };

            const result = await this.dynamodb.scan(params).promise();
            
            // Sort by timestamp descending
            const events = result.Items.sort((a, b) => 
                new Date(b.timestamp) - new Date(a.timestamp)
            );

            return events;
        } catch (error) {
            console.error('Failed to get recent events:', error);
            return [];
        }
    }

    /**
     * Process and store network events
     */
    async processNetworkData(currentData, previousData) {
        const events = [];
        
        try {
            // Compare current vs previous data to detect events
            const deviceEvents = this.detectDeviceEvents(currentData, previousData);
            const performanceEvents = this.detectPerformanceEvents(currentData, previousData);
            const apEvents = this.detectAPEvents(currentData, previousData);

            events.push(...deviceEvents, ...performanceEvents, ...apEvents);

            // Store events in DynamoDB
            for (const event of events) {
                await this.storeEvent(event);
            }

            return events;
        } catch (error) {
            console.error('Failed to process network data:', error);
            return [];
        }
    }

    /**
     * Detect device connection/disconnection events
     */
    detectDeviceEvents(currentData, previousData) {
        const events = [];
        
        if (!previousData || !currentData) {
            return events;
        }

        // Create device maps for comparison
        const currentDevices = new Map();
        const previousDevices = new Map();

        currentData.forEach(network => {
            network.devices.forEach(device => {
                currentDevices.set(device.mac, {
                    ...device,
                    networkId: network.id,
                    networkName: network.name
                });
            });
        });

        previousData.forEach(network => {
            network.devices.forEach(device => {
                previousDevices.set(device.mac, {
                    ...device,
                    networkId: network.id,
                    networkName: network.name
                });
            });
        });

        // Detect new connections
        currentDevices.forEach((device, mac) => {
            if (!previousDevices.has(mac)) {
                events.push({
                    type: 'device_connected',
                    deviceMac: mac,
                    deviceName: device.nickname || device.hostname || 'Unknown Device',
                    networkId: device.networkId,
                    networkName: device.networkName,
                    timestamp: new Date().toISOString(),
                    isNewDevice: !this.isKnownDevice(mac)
                });
            }
        });

        // Detect disconnections
        previousDevices.forEach((device, mac) => {
            if (!currentDevices.has(mac)) {
                events.push({
                    type: 'device_disconnected',
                    deviceMac: mac,
                    deviceName: device.nickname || device.hostname || 'Unknown Device',
                    networkId: device.networkId,
                    networkName: device.networkName,
                    timestamp: new Date().toISOString()
                });
            }
        });

        return events;
    }

    /**
     * Detect network performance events
     */
    detectPerformanceEvents(currentData, previousData) {
        const events = [];
        
        if (!previousData || !currentData) {
            return events;
        }

        currentData.forEach(network => {
            const previousNetwork = previousData.find(n => n.id === network.id);
            if (!previousNetwork) return;

            // Check for significant device count changes
            const deviceCountChange = network.totalDevices - previousNetwork.totalDevices;
            const changePercentage = Math.abs(deviceCountChange) / Math.max(previousNetwork.totalDevices, 1);

            if (changePercentage > 0.5 && Math.abs(deviceCountChange) > 3) {
                events.push({
                    type: 'significant_device_change',
                    networkId: network.id,
                    networkName: network.name,
                    previousCount: previousNetwork.totalDevices,
                    currentCount: network.totalDevices,
                    change: deviceCountChange,
                    timestamp: new Date().toISOString()
                });
            }

            // Check for AP load imbalances
            const apLoadImbalance = this.detectAPLoadImbalance(network.accessPoints);
            if (apLoadImbalance) {
                events.push({
                    type: 'ap_load_imbalance',
                    networkId: network.id,
                    networkName: network.name,
                    details: apLoadImbalance,
                    timestamp: new Date().toISOString()
                });
            }
        });

        return events;
    }

    /**
     * Detect access point events
     */
    detectAPEvents(currentData, previousData) {
        const events = [];
        
        if (!previousData || !currentData) {
            return events;
        }

        currentData.forEach(network => {
            const previousNetwork = previousData.find(n => n.id === network.id);
            if (!previousNetwork) return;

            // Create AP maps for comparison
            const currentAPs = new Map();
            const previousAPs = new Map();

            network.accessPoints.forEach(ap => {
                currentAPs.set(ap.url, ap);
            });

            previousNetwork.accessPoints.forEach(ap => {
                previousAPs.set(ap.url, ap);
            });

            // Detect AP status changes
            currentAPs.forEach((ap, url) => {
                const previousAP = previousAPs.get(url);
                if (previousAP) {
                    // Check for significant device count changes on AP
                    const deviceChange = ap.deviceCount - previousAP.deviceCount;
                    if (Math.abs(deviceChange) > 5) {
                        events.push({
                            type: 'ap_device_change',
                            networkId: network.id,
                            networkName: network.name,
                            apName: ap.nickname || ap.model || 'Access Point',
                            previousDevices: previousAP.deviceCount,
                            currentDevices: ap.deviceCount,
                            change: deviceChange,
                            timestamp: new Date().toISOString()
                        });
                    }
                }
            });
        });

        return events;
    }

    /**
     * Detect AP load imbalance
     */
    detectAPLoadImbalance(accessPoints) {
        if (!accessPoints || accessPoints.length < 2) {
            return null;
        }

        const deviceCounts = accessPoints.map(ap => ap.deviceCount || 0);
        const maxDevices = Math.max(...deviceCounts);
        const minDevices = Math.min(...deviceCounts);
        const avgDevices = deviceCounts.reduce((sum, count) => sum + count, 0) / deviceCounts.length;

        // Consider imbalanced if max is more than 3x the average and difference > 10
        if (maxDevices > avgDevices * 3 && (maxDevices - minDevices) > 10) {
            const busiestAP = accessPoints.find(ap => ap.deviceCount === maxDevices);
            const lightestAP = accessPoints.find(ap => ap.deviceCount === minDevices);

            return {
                busiestAP: busiestAP.nickname || busiestAP.model || 'Unknown AP',
                busiestCount: maxDevices,
                lightestAP: lightestAP.nickname || lightestAP.model || 'Unknown AP',
                lightestCount: minDevices,
                imbalanceRatio: maxDevices / Math.max(minDevices, 1)
            };
        }

        return null;
    }

    /**
     * Check if device is known (has been seen before)
     */
    async isKnownDevice(mac) {
        try {
            const params = {
                TableName: this.tableName,
                FilterExpression: 'deviceMac = :mac',
                ExpressionAttributeValues: {
                    ':mac': mac
                },
                Limit: 1
            };

            const result = await this.dynamodb.scan(params).promise();
            return result.Items.length > 0;
        } catch (error) {
            console.error('Failed to check known device:', error);
            return false;
        }
    }

    /**
     * Store event in DynamoDB
     */
    async storeEvent(event) {
        try {
            const params = {
                TableName: this.tableName,
                Item: {
                    id: `${event.type}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                    ...event,
                    ttl: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60) // 30 days TTL
                }
            };

            await this.dynamodb.put(params).promise();
            console.log('Event stored:', event.type);
        } catch (error) {
            console.error('Failed to store event:', error);
        }
    }

    /**
     * Get event summary for a time period
     */
    async getEventSummary(hours = 24) {
        const events = await this.getRecentEvents(hours);
        
        const summary = {
            totalEvents: events.length,
            deviceConnections: events.filter(e => e.type === 'device_connected').length,
            deviceDisconnections: events.filter(e => e.type === 'device_disconnected').length,
            newDevices: events.filter(e => e.type === 'device_connected' && e.isNewDevice).length,
            performanceAlerts: events.filter(e => e.type.includes('performance') || e.type.includes('imbalance')).length,
            apEvents: events.filter(e => e.type.startsWith('ap_')).length
        };

        return summary;
    }

    /**
     * Clean up old events (called periodically)
     */
    async cleanupOldEvents() {
        try {
            const cutoffTime = moment().subtract(30, 'days').toISOString();
            
            const params = {
                TableName: this.tableName,
                FilterExpression: '#timestamp < :cutoff',
                ExpressionAttributeNames: {
                    '#timestamp': 'timestamp'
                },
                ExpressionAttributeValues: {
                    ':cutoff': cutoffTime
                }
            };

            const result = await this.dynamodb.scan(params).promise();
            
            // Delete old events in batches
            const deletePromises = result.Items.map(item => {
                return this.dynamodb.delete({
                    TableName: this.tableName,
                    Key: { id: item.id }
                }).promise();
            });

            await Promise.all(deletePromises);
            console.log(`Cleaned up ${result.Items.length} old events`);
        } catch (error) {
            console.error('Failed to cleanup old events:', error);
        }
    }
}

module.exports = EventProcessor;