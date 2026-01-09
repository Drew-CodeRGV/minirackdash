const Alexa = require('ask-sdk-core');
const axios = require('axios');

// Pi Dashboard Configuration
const PI_DASHBOARD_HOST = process.env.PI_DASHBOARD_IP || 'localhost';
const PI_DASHBOARD_PORT = process.env.PI_DASHBOARD_PORT || '80';
const PI_BASE_URL = `http://${PI_DASHBOARD_HOST}${PI_DASHBOARD_PORT !== '80' ? ':' + PI_DASHBOARD_PORT : ''}`;

// Response cache to reduce Pi load
const responseCache = new Map();
const CACHE_DURATION = 30000; // 30 seconds

/**
 * Make API call to Raspberry Pi dashboard
 */
async function callPiAPI(endpoint) {
    const cacheKey = endpoint;
    const cached = responseCache.get(cacheKey);
    
    // Return cached response if still valid
    if (cached && (Date.now() - cached.timestamp) < CACHE_DURATION) {
        console.log(`Using cached response for ${endpoint}`);
        return cached.data;
    }
    
    try {
        console.log(`Calling Pi API: ${PI_BASE_URL}${endpoint}`);
        const response = await axios.get(`${PI_BASE_URL}${endpoint}`, {
            timeout: 8000,
            headers: {
                'User-Agent': 'EeroDashboard-Echo/1.0'
            }
        });
        
        // Cache the response
        responseCache.set(cacheKey, {
            data: response.data,
            timestamp: Date.now()
        });
        
        return response.data;
    } catch (error) {
        console.error(`Pi API call failed for ${endpoint}:`, error.message);
        
        // Return cached data if available, even if expired
        if (cached) {
            console.log(`Using expired cache for ${endpoint} due to error`);
            return cached.data;
        }
        
        throw new Error(`Unable to connect to your dashboard. Please make sure your Raspberry Pi is online.`);
    }
}

/**
 * Format numbers for voice
 */
function formatNumberForVoice(num) {
    if (num === 0) return 'no';
    if (num === 1) return 'one';
    if (num === 2) return 'two';
    if (num === 3) return 'three';
    if (num <= 20) return num.toString();
    return num.toString();
}

/**
 * Build device count response from Pi data
 */
function buildDeviceCountResponse(data) {
    const totalDevices = data.total_devices || 0;
    const wirelessDevices = data.wireless_devices || 0;
    const wiredDevices = data.wired_devices || 0;
    
    if (totalDevices === 0) {
        return "No devices are currently connected to your network.";
    }
    
    let response = `You have ${formatNumberForVoice(totalDevices)} device${totalDevices !== 1 ? 's' : ''} connected to your network. `;
    
    if (wirelessDevices > 0 && wiredDevices > 0) {
        response += `${formatNumberForVoice(wirelessDevices)} ${wirelessDevices === 1 ? 'is' : 'are'} wireless and ${formatNumberForVoice(wiredDevices)} ${wiredDevices === 1 ? 'is' : 'are'} wired. `;
    } else if (wirelessDevices > 0) {
        response += `All are connected wirelessly. `;
    } else if (wiredDevices > 0) {
        response += `All are wired connections. `;
    }
    
    // Add AP info if available
    if (data.busiest_ap && data.busiest_ap.device_count > 0) {
        const apName = data.busiest_ap.name || 'access point';
        response += `Your busiest access point is ${apName} with ${formatNumberForVoice(data.busiest_ap.device_count)} device${data.busiest_ap.device_count !== 1 ? 's' : ''}.`;
    }
    
    return response;
}

/**
 * Build network status response from Pi data
 */
function buildNetworkStatusResponse(data) {
    let response = "Your network is running smoothly. ";
    
    const totalDevices = data.total_devices || 0;
    const totalAPs = data.total_aps || 0;
    const onlineAPs = data.online_aps || totalAPs;
    
    if (totalDevices > 0) {
        response += `${formatNumberForVoice(totalDevices)} device${totalDevices !== 1 ? 's are' : ' is'} currently connected. `;
    }
    
    if (totalAPs > 0) {
        if (onlineAPs === totalAPs) {
            response += `All ${formatNumberForVoice(totalAPs)} access point${totalAPs !== 1 ? 's are' : ' is'} online with good coverage. `;
        } else {
            response += `${formatNumberForVoice(onlineAPs)} of ${formatNumberForVoice(totalAPs)} access points are online. `;
        }
    }
    
    if (data.internet_status === 'connected') {
        response += "Internet connectivity is excellent.";
    } else {
        response += "There may be an internet connectivity issue.";
    }
    
    return response;
}

/**
 * Build device types response from Pi data
 */
function buildDeviceTypesResponse(data) {
    const deviceTypes = data.device_types || {};
    const typeNames = {
        iOS: 'iPhone and iPad',
        Android: 'Android device',
        Windows: 'Windows computer',
        Amazon: 'Amazon device',
        Gaming: 'gaming device',
        Streaming: 'streaming device',
        Other: 'other device'
    };
    
    const connectedTypes = [];
    
    Object.entries(deviceTypes).forEach(([type, count]) => {
        if (count > 0) {
            const name = typeNames[type] || type.toLowerCase();
            connectedTypes.push(`${formatNumberForVoice(count)} ${name}${count !== 1 ? 's' : ''}`);
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

// Launch Request Handler
const LaunchRequestHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'LaunchRequest';
    },
    async handle(handlerInput) {
        try {
            const data = await callPiAPI('/api/voice/status');
            const deviceCount = data.total_devices || 0;
            
            let speakOutput = `Welcome to your Eero Dashboard! `;
            
            if (deviceCount > 0) {
                speakOutput += `You currently have ${formatNumberForVoice(deviceCount)} device${deviceCount !== 1 ? 's' : ''} connected to your network. `;
            }
            
            speakOutput += `What would you like to know about your network?`;
            
            return handlerInput.responseBuilder
                .speak(speakOutput)
                .reprompt('What would you like to know about your network?')
                .getResponse();
        } catch (error) {
            console.error('Launch error:', error);
            return handlerInput.responseBuilder
                .speak('Welcome to Eero Dashboard. I\'m having trouble connecting to your Raspberry Pi right now. Please make sure it\'s online and try again.')
                .getResponse();
        }
    }
};

// Device Count Intent Handler
const DeviceCountIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'DeviceCountIntent';
    },
    async handle(handlerInput) {
        try {
            const data = await callPiAPI('/api/voice/devices');
            const response = buildDeviceCountResponse(data);
            
            return handlerInput.responseBuilder
                .speak(response)
                .getResponse();
        } catch (error) {
            console.error('Device count error:', error);
            return handlerInput.responseBuilder
                .speak('I\'m having trouble getting your device information from the Raspberry Pi. Please check that it\'s online and try again.')
                .getResponse();
        }
    }
};

// Network Status Intent Handler
const NetworkStatusIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'NetworkStatusIntent';
    },
    async handle(handlerInput) {
        try {
            const data = await callPiAPI('/api/voice/status');
            const response = buildNetworkStatusResponse(data);
            
            return handlerInput.responseBuilder
                .speak(response)
                .getResponse();
        } catch (error) {
            console.error('Network status error:', error);
            return handlerInput.responseBuilder
                .speak('I\'m unable to check your network status right now. Please make sure your Raspberry Pi dashboard is running and try again.')
                .getResponse();
        }
    }
};

// Device Types Intent Handler
const DeviceTypesIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'DeviceTypesIntent';
    },
    async handle(handlerInput) {
        try {
            const data = await callPiAPI('/api/voice/devices');
            const response = buildDeviceTypesResponse(data);
            
            return handlerInput.responseBuilder
                .speak(response)
                .getResponse();
        } catch (error) {
            console.error('Device types error:', error);
            return handlerInput.responseBuilder
                .speak('I can\'t get device type information from your Pi right now. Please try again.')
                .getResponse();
        }
    }
};

// AP Performance Intent Handler
const APPerformanceIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'APPerformanceIntent';
    },
    async handle(handlerInput) {
        try {
            const data = await callPiAPI('/api/voice/aps');
            
            let response = `You have ${formatNumberForVoice(data.total_aps || 0)} access point${(data.total_aps || 0) !== 1 ? 's' : ''} online. `;
            
            if (data.busiest_ap && data.busiest_ap.device_count > 0) {
                const apName = data.busiest_ap.name || 'access point';
                response += `Your busiest access point is ${apName} with ${formatNumberForVoice(data.busiest_ap.device_count)} device${data.busiest_ap.device_count !== 1 ? 's' : ''}. `;
            }
            
            response += "All access points are performing well with good signal coverage.";
            
            return handlerInput.responseBuilder
                .speak(response)
                .getResponse();
        } catch (error) {
            console.error('AP performance error:', error);
            return handlerInput.responseBuilder
                .speak('I\'m unable to get access point information from your Pi right now. Please try again.')
                .getResponse();
        }
    }
};

// Recent Events Intent Handler
const RecentEventsIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'RecentEventsIntent';
    },
    async handle(handlerInput) {
        try {
            const data = await callPiAPI('/api/voice/events');
            
            if (!data.events || data.events.length === 0) {
                return handlerInput.responseBuilder
                    .speak('No recent network events to report. Your network has been stable.')
                    .getResponse();
            }
            
            let response = "Here's your recent network activity: ";
            const recentEvents = data.events.slice(0, 3); // Limit to 3 events for voice
            
            const eventDescriptions = recentEvents.map(event => {
                if (event.type === 'device_connected') {
                    return `${event.device_name || 'A device'} connected`;
                } else if (event.type === 'device_disconnected') {
                    return `${event.device_name || 'A device'} disconnected`;
                } else {
                    return 'A network event occurred';
                }
            });
            
            if (eventDescriptions.length === 1) {
                response += eventDescriptions[0];
            } else if (eventDescriptions.length === 2) {
                response += `${eventDescriptions[0]} and ${eventDescriptions[1]}`;
            } else {
                response += `${eventDescriptions[0]}, ${eventDescriptions[1]}, and ${eventDescriptions[2]}`;
            }
            
            response += " in the last hour.";
            
            return handlerInput.responseBuilder
                .speak(response)
                .getResponse();
        } catch (error) {
            console.error('Recent events error:', error);
            return handlerInput.responseBuilder
                .speak('I\'m having trouble accessing recent network events from your Pi. Please try again.')
                .getResponse();
        }
    }
};

// Help Intent Handler
const HelpIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.HelpIntent';
    },
    handle(handlerInput) {
        const speakOutput = `I can help you monitor your Eero network using data from your Raspberry Pi. You can ask me things like:
            How many devices are connected?
            What's my network status?
            Tell me about device types.
            How are my access points performing?
            What would you like to know?`;

        return handlerInput.responseBuilder
            .speak(speakOutput)
            .reprompt(speakOutput)
            .getResponse();
    }
};

// Cancel and Stop Intent Handler
const CancelAndStopIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && (Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.CancelIntent'
                || Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.StopIntent');
    },
    handle(handlerInput) {
        const speakOutput = 'Goodbye! Your network is in good hands with your Raspberry Pi.';

        return handlerInput.responseBuilder
            .speak(speakOutput)
            .getResponse();
    }
};

// Fallback Intent Handler
const FallbackIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.FallbackIntent';
    },
    handle(handlerInput) {
        const speakOutput = `I'm not sure how to help with that. I can tell you about your network devices, status, and access points using data from your Raspberry Pi. What would you like to know?`;

        return handlerInput.responseBuilder
            .speak(speakOutput)
            .reprompt(speakOutput)
            .getResponse();
    }
};

// Session Ended Request Handler
const SessionEndedRequestHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'SessionEndedRequest';
    },
    handle(handlerInput) {
        console.log(`Session ended: ${JSON.stringify(handlerInput.requestEnvelope)}`);
        return handlerInput.responseBuilder.getResponse();
    }
};

// Generic Error Handler
const ErrorHandler = {
    canHandle() {
        return true;
    },
    handle(handlerInput, error) {
        const speakOutput = 'Sorry, I had trouble connecting to your Raspberry Pi. Please make sure it\'s online and try again.';
        console.log(`Error handled: ${JSON.stringify(error)}`);

        return handlerInput.responseBuilder
            .speak(speakOutput)
            .reprompt(speakOutput)
            .getResponse();
    }
};

// Request Interceptor (for logging)
const RequestInterceptor = {
    process(handlerInput) {
        console.log(`Incoming request: ${JSON.stringify(handlerInput.requestEnvelope)}`);
        console.log(`Pi Dashboard URL: ${PI_BASE_URL}`);
    }
};

// Response Interceptor (for logging)
const ResponseInterceptor = {
    process(handlerInput, response) {
        console.log(`Outgoing response: ${JSON.stringify(response)}`);
    }
};

// Lambda handler
exports.handler = Alexa.SkillBuilders.custom()
    .addRequestHandlers(
        LaunchRequestHandler,
        DeviceCountIntentHandler,
        NetworkStatusIntentHandler,
        DeviceTypesIntentHandler,
        APPerformanceIntentHandler,
        RecentEventsIntentHandler,
        HelpIntentHandler,
        CancelAndStopIntentHandler,
        FallbackIntentHandler,
        SessionEndedRequestHandler
    )
    .addErrorHandlers(ErrorHandler)
    .addRequestInterceptors(RequestInterceptor)
    .addResponseInterceptors(ResponseInterceptor)
    .withCustomUserAgent('eero-dashboard-echo-pi/1.0')
    .lambda();