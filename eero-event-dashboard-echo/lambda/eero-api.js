const axios = require('axios');
const AWS = require('aws-sdk');

class EeroAPI {
    constructor() {
        this.apiUrl = process.env.EERO_API_URL || 'api-user.e2ro.com';
        this.baseURL = `https://${this.apiUrl}/2.2`;
        this.ssm = new AWS.SSM();
        this.tokens = new Map();
    }

    /**
     * Get encrypted API token from Parameter Store
     */
    async getToken(networkId) {
        if (this.tokens.has(networkId)) {
            return this.tokens.get(networkId);
        }

        try {
            const paramName = `/eero-dashboard/tokens/${networkId}`;
            const result = await this.ssm.getParameter({
                Name: paramName,
                WithDecryption: true
            }).promise();

            const token = result.Parameter.Value;
            this.tokens.set(networkId, token);
            return token;
        } catch (error) {
            console.error(`Failed to get token for network ${networkId}:`, error);
            throw new Error('Authentication failed');
        }
    }

    /**
     * Get request headers for API calls
     */
    async getHeaders(networkId) {
        const token = await this.getToken(networkId);
        return {
            'Content-Type': 'application/json',
            'User-Agent': 'EeroDashboard-Echo/1.0',
            'X-User-Token': token
        };
    }

    /**
     * Get all configured networks from Parameter Store
     */
    async getNetworkIds() {
        try {
            const result = await this.ssm.getParametersByPath({
                Path: '/eero-dashboard/networks/',
                Recursive: true
            }).promise();

            return result.Parameters.map(param => {
                const networkId = param.Name.split('/').pop();
                return {
                    id: networkId,
                    name: param.Value
                };
            });
        } catch (error) {
            console.error('Failed to get network IDs:', error);
            return [];
        }
    }

    /**
     * Get basic network status
     */
    async getNetworkStatus() {
        const networks = await this.getNetworkIds();
        if (networks.length === 0) {
            throw new Error('No networks configured');
        }

        let totalDevices = 0;
        let totalNetworks = 0;
        let onlineNetworks = 0;

        for (const network of networks) {
            try {
                const devices = await this.getDevices(network.id);
                const connectedDevices = devices.filter(d => d.connected);
                
                totalDevices += connectedDevices.length;
                totalNetworks++;
                onlineNetworks++;
            } catch (error) {
                console.error(`Network ${network.id} error:`, error);
                totalNetworks++;
            }
        }

        return {
            totalDevices,
            totalNetworks,
            onlineNetworks,
            networks
        };
    }

    /**
     * Get all network data including devices and APs
     */
    async getAllNetworkData() {
        const networks = await this.getNetworkIds();
        const networkData = [];

        for (const network of networks) {
            try {
                const [devices, aps] = await Promise.all([
                    this.getDevices(network.id),
                    this.getAccessPoints(network.id)
                ]);

                const connectedDevices = devices.filter(d => d.connected);
                const deviceTypes = this.categorizeDevices(connectedDevices);

                networkData.push({
                    id: network.id,
                    name: network.name,
                    devices: connectedDevices,
                    deviceTypes,
                    accessPoints: aps,
                    totalDevices: connectedDevices.length,
                    wirelessDevices: connectedDevices.filter(d => d.wireless).length,
                    wiredDevices: connectedDevices.filter(d => !d.wireless).length
                });
            } catch (error) {
                console.error(`Failed to get data for network ${network.id}:`, error);
            }
        }

        return networkData;
    }

    /**
     * Get devices for a specific network
     */
    async getDevices(networkId) {
        try {
            const headers = await this.getHeaders(networkId);
            const response = await axios.get(`${this.baseURL}/networks/${networkId}/devices`, {
                headers,
                timeout: 10000
            });

            return response.data.data || [];
        } catch (error) {
            console.error(`Failed to get devices for network ${networkId}:`, error);
            throw error;
        }
    }

    /**
     * Get access points for a specific network
     */
    async getAccessPoints(networkId) {
        try {
            const headers = await this.getHeaders(networkId);
            const response = await axios.get(`${this.baseURL}/networks/${networkId}/eeros`, {
                headers,
                timeout: 10000
            });

            const aps = response.data.data || [];
            
            // Get device distribution per AP
            const devices = await this.getDevices(networkId);
            const connectedDevices = devices.filter(d => d.connected && d.wireless);

            return aps.map(ap => {
                const apDevices = this.getDevicesForAP(connectedDevices, ap);
                return {
                    ...ap,
                    deviceCount: apDevices.length,
                    devices: apDevices
                };
            });
        } catch (error) {
            console.error(`Failed to get APs for network ${networkId}:`, error);
            return [];
        }
    }

    /**
     * Get AP data across all networks
     */
    async getAPData() {
        const networks = await this.getNetworkIds();
        const allAPs = [];

        for (const network of networks) {
            try {
                const aps = await this.getAccessPoints(network.id);
                allAPs.push(...aps.map(ap => ({
                    ...ap,
                    networkName: network.name,
                    networkId: network.id
                })));
            } catch (error) {
                console.error(`Failed to get APs for network ${network.id}:`, error);
            }
        }

        return allAPs;
    }

    /**
     * Categorize devices by type
     */
    categorizeDevices(devices) {
        const categories = {
            phones: 0,
            laptops: 0,
            tablets: 0,
            smartHome: 0,
            gaming: 0,
            streaming: 0,
            other: 0
        };

        devices.forEach(device => {
            const type = this.detectDeviceType(device);
            categories[type]++;
        });

        return categories;
    }

    /**
     * Detect device type from manufacturer and hostname
     */
    detectDeviceType(device) {
        const manufacturer = (device.manufacturer || '').toLowerCase();
        const hostname = (device.hostname || '').toLowerCase();
        const text = `${manufacturer} ${hostname}`;

        // Phones
        if (text.includes('iphone') || text.includes('android') || 
            text.includes('samsung') && (text.includes('sm-') || text.includes('galaxy'))) {
            return 'phones';
        }

        // Laptops
        if (text.includes('macbook') || text.includes('laptop') || 
            text.includes('dell') || text.includes('hp') || text.includes('lenovo')) {
            return 'laptops';
        }

        // Tablets
        if (text.includes('ipad') || text.includes('tablet')) {
            return 'tablets';
        }

        // Gaming
        if (text.includes('playstation') || text.includes('xbox') || 
            text.includes('nintendo') || text.includes('steam')) {
            return 'gaming';
        }

        // Streaming
        if (text.includes('roku') || text.includes('chromecast') || 
            text.includes('apple tv') || text.includes('fire tv')) {
            return 'streaming';
        }

        // Smart Home
        if (text.includes('echo') || text.includes('alexa') || 
            text.includes('nest') || text.includes('ring') || 
            text.includes('philips hue') || text.includes('smart')) {
            return 'smartHome';
        }

        return 'other';
    }

    /**
     * Get devices connected to a specific AP
     */
    getDevicesForAP(devices, ap) {
        // This is a simplified version - in reality, you'd need to match
        // devices to APs based on BSSID or other connection data
        const apDevices = devices.filter(device => {
            // Match based on signal strength, frequency, or other indicators
            // This would need to be implemented based on actual Eero API response structure
            return device.interface && device.interface.eero_url === ap.url;
        });

        return apDevices;
    }
}

module.exports = EeroAPI;