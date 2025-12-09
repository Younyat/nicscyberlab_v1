/**
 * Initial Setup Service
 * Handles API calls for infrastructure initialization and destruction
 */

import { API_BASE, ENDPOINTS } from '../config.js';

/**
 * Request initial setup run
 * @param {Object} options - Configuration options
 * @returns {Promise<Object>} Response from backend
 */
export async function requestInitialRun(options = {}) {
    try {
        const response = await fetch(`${API_BASE}${ENDPOINTS.INITIAL_RUN}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                config_file: options.configFile || 'infrastructure/initial/configs/initial_config.json',
                log_file: options.logFile || 'infrastructure/initial/logs/initial_setup.log'
            })
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        return await response.json();
    } catch (error) {
        console.error('Error requesting initial run:', error);
        throw error;
    }
}

/**
 * Request initial setup destruction
 * @param {Object} options - Configuration options
 * @returns {Promise<Object>} Response from backend
 */
export async function requestInitialDestroy(options = {}) {
    try {
        const response = await fetch(`${API_BASE}${ENDPOINTS.INITIAL_DESTROY}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                log_file: options.logFile || 'infrastructure/initial/logs/initial_destroy.log'
            })
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        return await response.json();
    } catch (error) {
        console.error('Error requesting initial destroy:', error);
        throw error;
    }
}

export default {
    requestInitialRun,
    requestInitialDestroy
};
