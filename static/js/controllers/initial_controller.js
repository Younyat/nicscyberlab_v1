/**
 * Initial Setup Controller
 * Handles infrastructure initialization and destruction
 */

import { eventBus } from '../core/event_bus.js';
import { showToast } from '../ui/toast.js';
import { showConfirmationModal } from '../ui/modal.js';
import { showOverlay, lockButtons } from '../ui/overlay.js';
import { requestInitialRun, requestInitialDestroy } from '../services/initial_service.js';

class InitialController {
    constructor() {
        this.terminal = document.getElementById('initialTerm');
        this.btnInitialRun = document.getElementById('btn-initial-run');
        this.btnInitialDestroy = document.getElementById('btn-initial-destroy');
        this.setupStatus = document.getElementById('setupStatus');
        this.configFile = document.getElementById('configFile');
        this.logFile = document.getElementById('logFile');
    }

    /**
     * Initialize the controller
     */
    init() {
        this.bindEvents();
        this.initTerminal();
    }

    /**
     * Bind button and event listeners
     */
    bindEvents() {
        this.btnInitialRun.addEventListener('click', () => this.handleInitialRun());
        this.btnInitialDestroy.addEventListener('click', () => this.handleInitialDestroy());

        // Listen to event bus messages
        eventBus.on('initial:output', (msg) => {
            this.appendTerminal(msg.message, msg.type || 'info');
        });

        eventBus.on('initial:status', (status) => {
            this.updateStatus(status);
        });
    }

    /**
     * Initialize terminal view
     */
    initTerminal() {
        this.terminal.innerHTML = `
            <div class="terminal-line" style="color: #daa520;">
                <i class="fas fa-info-circle"></i> Initial Setup Terminal Ready
            </div>
            <div class="terminal-line" style="color: #999;">
                Configuration: ${this.configFile.value}
            </div>
            <div class="terminal-line" style="color: #999;">
                Log file: ${this.logFile.value}
            </div>
        `;
    }

    /**
     * Handle initial run
     */
    async handleInitialRun() {
        showConfirmationModal(
            'Run Initial Setup',
            'This will initialize the OpenStack infrastructure. Continue?',
            async () => {
                try {
                    lockButtons([this.btnInitialRun, this.btnInitialDestroy], true);
                    showOverlay();
                    this.appendTerminal('Starting initial setup...', 'running');
                    this.updateStatus('Running initial setup...');

                    const response = await requestInitialRun({
                        configFile: this.configFile.value,
                        logFile: this.logFile.value
                    });

                    if (response.status === 'success') {
                        this.appendTerminal('✓ Initial setup completed successfully', 'success');
                        this.updateStatus('Setup completed successfully');
                        showToast('Initial setup completed!');
                    } else {
                        throw new Error(response.message || 'Setup failed');
                    }
                } catch (error) {
                    console.error('Error during initial run:', error);
                    this.appendTerminal(`✗ Error: ${error.message}`, 'error');
                    this.updateStatus('Setup failed - check terminal for details');
                    showToast(`Error: ${error.message}`, 'error');
                } finally {
                    lockButtons([this.btnInitialRun, this.btnInitialDestroy], false);
                    showOverlay(false);
                }
            }
        );
    }

    /**
     * Handle initial destroy
     */
    async handleInitialDestroy() {
        showConfirmationModal(
            'Destroy Infrastructure',
            'This will destroy the OpenStack infrastructure. Are you sure?',
            async () => {
                try {
                    lockButtons([this.btnInitialRun, this.btnInitialDestroy], true);
                    showOverlay();
                    this.appendTerminal('Starting infrastructure destruction...', 'running');
                    this.updateStatus('Destroying infrastructure...');

                    const response = await requestInitialDestroy({
                        logFile: this.logFile.value
                    });

                    if (response.status === 'success') {
                        this.appendTerminal('✓ Infrastructure destroyed successfully', 'success');
                        this.updateStatus('Destroyed successfully');
                        showToast('Infrastructure destroyed!');
                    } else {
                        throw new Error(response.message || 'Destruction failed');
                    }
                } catch (error) {
                    console.error('Error during initial destroy:', error);
                    this.appendTerminal(`✗ Error: ${error.message}`, 'error');
                    this.updateStatus('Destruction failed - check terminal for details');
                    showToast(`Error: ${error.message}`, 'error');
                } finally {
                    lockButtons([this.btnInitialRun, this.btnInitialDestroy], false);
                    showOverlay(false);
                }
            }
        );
    }

    /**
     * Append message to terminal
     */
    appendTerminal(message, type = 'info') {
        const line = document.createElement('div');
        line.className = `terminal-line`;

        if (type === 'running') {
            line.className += ' running';
            line.innerHTML = `<i class="fas fa-spinner fa-spin"></i> ${message}`;
        } else if (type === 'success') {
            line.className += ' success';
            line.innerHTML = `<i class="fas fa-check-circle"></i> ${message}`;
        } else if (type === 'error') {
            line.className += ' error';
            line.innerHTML = `<i class="fas fa-times-circle"></i> ${message}`;
        } else {
            line.innerHTML = `<i class="fas fa-info-circle"></i> ${message}`;
        }

        this.terminal.appendChild(line);
        this.terminal.scrollTop = this.terminal.scrollHeight;
    }

    /**
     * Update status display
     */
    updateStatus(status) {
        this.setupStatus.textContent = status;
    }
}

// Initialize controller when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    const controller = new InitialController();
    controller.init();
});

export { InitialController };
