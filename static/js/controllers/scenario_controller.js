/**
 * Scenario Controller - Editor de Escenarios
 * Integra Cytoscape, interfaz y backend
 */

import { showToast } from '../ui/toast.js';
import { showConfirmationModal } from '../ui/modal.js';
import { showOverlay } from '../ui/overlay.js';
import {
  createScenarioOnBackend,
  getScenarioFromBackend,
  getDeploymentStatus,
  destroyScenarioOnBackend
} from '../services/scenario_service.js';

class ScenarioController {
  constructor() {
    this.cy = null;
    this.nodeCounter = 0;
    this.currentMode = 'select';
    this.selectedNodes = [];
    this.connectionMode = false;
    this.terminal = document.getElementById('terminal-output');
  }

  init() {
    this.initCytoscape();
    this.bindEvents();
  }

  initCytoscape() {
    const cyContainer = document.getElementById('cy');
    if (!cyContainer || typeof cytoscape === 'undefined') return;

    this.cy = cytoscape({
      container: cyContainer,
      elements: [],
      style: [
        {
          selector: 'node',
          style: {
            'width': 60, 'height': 60, 'label': 'data(name)', 'text-valign': 'bottom',
            'text-margin-y': 5, 'color': '#f0f0f0', 'text-outline-width': 2,
            'text-outline-color': '#1e1e1e', 'border-width': 4, 'border-opacity': 0.8,
            'cursor': 'grab', 'font-size': '12px', 'font-weight': 'bold'
          }
        },
        { selector: 'node[type="monitor"]', style: { 'background-color': '#388e3c', 'border-color': '#66bb6a', 'shape': 'round-rectangle' } },
        { selector: 'node[type="attack"]', style: { 'background-color': '#e53935', 'border-color': '#ef9a9a', 'shape': 'triangle' } },
        { selector: 'node[type="victim"]', style: { 'background-color': '#1976d2', 'border-color': '#64b5f6', 'shape': 'ellipse' } },
        { selector: 'node:selected', style: { 'border-width': 5, 'border-color': '#00b0ff' } },
        { selector: 'edge', style: { 'width': 2, 'line-color': '#999', 'target-arrow-color': '#999', 'target-arrow-shape': 'triangle', 'curve-style': 'bezier' } },
        { selector: 'edge:selected', style: { 'line-color': '#f97316', 'target-arrow-color': '#f97316', 'width': 3 } }
      ],
      layout: { name: 'preset' },
      wheelSensitivity: 0.2, minZoom: 0.5, maxZoom: 3
    });

    this.updateStats();
  }

  bindEvents() {
    this.cy.on('tap', (evt) => {
      if (evt.target === this.cy && this.currentMode !== 'select' && this.currentMode !== 'connect') {
        this.addNode(evt.position.x, evt.position.y);
      }
    });

    this.cy.on('select', 'node', (evt) => {
      this.loadNodeProperties(evt.target);
      this.enableUpdateButton();
      if (this.connectionMode) {
        this.selectedNodes.push(evt.target);
        if (this.selectedNodes.length === 2) {
          this.connectNodes(this.selectedNodes[0], this.selectedNodes[1]);
          this.selectedNodes = [];
          this.toggleConnectionMode();
        }
      }
    });

    this.cy.on('unselect', 'node', () => {
      if (this.cy.$('node:selected').length === 0) {
        this.clearNodeProperties();
        this.disableUpdateButton();
      }
    });

    this.cy.on('dblclick', 'node', (evt) => {
      this.requestConsole(evt.target.data('name'));
    });

    this.bindButtonEvents();
  }

  bindButtonEvents() {
    // Mode buttons (Monitor, Attack, Victim)
    document.getElementById('btn-monitor')?.addEventListener('click', () => this.addNodeMode('monitor'));
    document.getElementById('btn-attack')?.addEventListener('click', () => this.addNodeMode('attack'));
    document.getElementById('btn-victim')?.addEventListener('click', () => this.addNodeMode('victim'));

    // Action buttons
    document.getElementById('btn-connect')?.addEventListener('click', () => this.toggleConnectionMode());
    document.getElementById('btn-delete')?.addEventListener('click', () => this.deleteSelected());
    document.getElementById('btn-clear')?.addEventListener('click', () => this.showClearConfirmation());
    document.getElementById('btn-update-node')?.addEventListener('click', () => this.updateNodeProperties());

    // Scenario buttons
    document.getElementById('btn-create')?.addEventListener('click', () => this.newScenarioConfirmation());
    document.getElementById('btn-load')?.addEventListener('click', () => this.loadScenario());
    document.getElementById('btn-destroy')?.addEventListener('click', () => this.destruirScenarioConfirmation());

    // Form inputs change listeners
    ['nodeNetwork', 'nodeSubNetwork', 'nodeImage', 'nodeFlavor', 'nodeSecurityGroup', 'nodeSSHKey'].forEach(id => {
      document.getElementById(id)?.addEventListener('change', () => this.updateNodeProperties(false));
    });
  }

  addNodeMode(type) {
    this.currentMode = type;
    if (this.connectionMode) this.toggleConnectionMode();
    showToast(`Modo: añadir ${type}`);
  }

  addNode(x, y) {
    this.nodeCounter++;
    const nodeId = `node${this.nodeCounter}`;
    const nodeData = {
      id: nodeId, name: `${this.currentMode} ${this.nodeCounter}`, type: this.currentMode,
      os: 'Debian-12', ip: `192.168.1.${100 + this.nodeCounter}`, network: 'private-net',
      subnetwork: 'private-subnet', flavor: 'medium', image: 'ubuntu-22.04',
      securityGroup: 'allow-ssh-icmp', sshKey: 'cyberlab-key'
    };
    this.cy.add({ group: 'nodes', data: nodeData, position: { x, y } });
    this.currentMode = 'select';
    this.updateStats();
    showToast('Nodo añadido');
  }

  toggleConnectionMode() {
    this.connectionMode = !this.connectionMode;
    this.selectedNodes = [];
    this.currentMode = this.connectionMode ? 'connect' : 'select';
    const btn = document.querySelector('.btn-connect');
    if (btn) {
      if (this.connectionMode) {
        btn.innerHTML = '<i class="fas fa-times mr-1"></i> Cancelar';
        btn.style.background = '#dc2626';
      } else {
        btn.innerHTML = '<i class="fas fa-link text-lg"></i><span class="mt-1">Conectar</span>';
        btn.style.background = '#ea580c';
      }
    }
  }

  connectNodes(node1, node2) {
    const edgeId = `edge_${node1.id()}_${node2.id()}`;
    if (this.cy.getElementById(edgeId).length > 0) {
      showToast('La conexión ya existe');
      return;
    }
    this.cy.add({ group: 'edges', data: { id: edgeId, source: node1.id(), target: node2.id() } });
    this.updateStats();
    showToast('Nodos conectados');
  }

  deleteSelected() {
    const selected = this.cy.$(':selected');
    if (selected.length === 0) {
      showToast('Selecciona algo para eliminar');
      return;
    }
    selected.remove();
    this.updateStats();
    this.clearNodeProperties();
    showToast('Eliminado');
  }

  showClearConfirmation() {
    showConfirmationModal('Confirmar Limpieza', '¿Estás seguro de que deseas eliminar todos los nodos?', () => this.clearAll());
  }

  clearAll() {
    this.cy.elements().remove();
    this.nodeCounter = 0;
    this.updateStats();
    this.clearNodeProperties();
    showToast('Escenario limpiado');
  }

  loadNodeProperties(node) {
    document.getElementById('nodeNetwork').value = node.data('network') || 'private-net';
    document.getElementById('nodeSubNetwork').value = node.data('subnetwork') || 'private-subnet';
    document.getElementById('nodeFlavor').value = node.data('flavor') || 'medium';
    document.getElementById('nodeImage').value = node.data('image') || 'ubuntu-22.04';
    document.getElementById('nodeSecurityGroup').value = node.data('securityGroup') || 'allow-ssh-icmp';
    document.getElementById('nodeSSHKey').value = node.data('sshKey') || 'cyberlab-key';
  }

  clearNodeProperties() {
    const defaults = {
      'nodeNetwork': 'private-net',
      'nodeSubNetwork': 'private-subnet',
      'nodeFlavor': 'medium',
      'nodeImage': 'ubuntu-22.04',
      'nodeSecurityGroup': 'allow-ssh-icmp',
      'nodeSSHKey': 'cyberlab-key'
    };
    Object.entries(defaults).forEach(([id, value]) => {
      const el = document.getElementById(id);
      if (el) el.value = value;
    });
  }

  updateNodeProperties(showToastMsg = true) {
    const selected = this.cy.$('node:selected');
    if (selected.length === 0) {
      if (showToastMsg) showToast('Selecciona un nodo');
      return;
    }
    const node = selected[0];
    node.data('network', document.getElementById('nodeNetwork').value);
    node.data('subnetwork', document.getElementById('nodeSubNetwork').value);
    node.data('flavor', document.getElementById('nodeFlavor').value);
    node.data('image', document.getElementById('nodeImage').value);
    node.data('securityGroup', document.getElementById('nodeSecurityGroup').value);
    node.data('sshKey', document.getElementById('nodeSSHKey').value);
    if (showToastMsg) showToast('Nodo actualizado');
  }

  updateStats() {
    document.getElementById('nodeCount').textContent = this.cy.nodes().length;
    document.getElementById('edgeCount').textContent = this.cy.edges().length;
  }

  enableUpdateButton() {
    const btn = document.getElementById('update-node-btn');
    if (btn) {
      btn.disabled = false;
      btn.classList.remove('cursor-not-allowed', 'bg-yellow-600/50');
      btn.classList.add('bg-yellow-600');
    }
  }

  disableUpdateButton() {
    const btn = document.getElementById('update-node-btn');
    if (btn) {
      btn.disabled = true;
      btn.classList.add('cursor-not-allowed', 'bg-yellow-600/50');
      btn.classList.remove('bg-yellow-600');
    }
  }

  getScenarioData() {
    const nodes = this.cy.nodes().map(node => ({
      id: node.data('id'), name: node.data('name'), type: node.data('type'),
      position: node.position(),
      properties: {
        os: node.data('image'), ip: node.data('ip'), network: node.data('network'),
        subnetwork: node.data('subnetwork'), flavor: node.data('flavor'),
        image: node.data('image'), securityGroup: node.data('securityGroup'),
        sshKey: node.data('sshKey')
      }
    }));
    const edges = this.cy.edges().map(edge => ({
      id: edge.data('id'), source: edge.data('source'), target: edge.data('target')
    }));
    return { scenario_name: 'file', nodes, edges };
  }

  newScenarioConfirmation() {
    showConfirmationModal('¿Crear un nuevo escenario?', '¿Estás seguro?', () => this.createScenario());
  }

  async createScenario() {
    this.updateNodeProperties(false);
    const data = this.getScenarioData();
    this.blockUI();
    showToast('⏳ Creando escenario...');
    this.appendToTerminal('$ ⏳ Iniciando creación...', 'text-yellow-400');

    try {
      const response = await createScenarioOnBackend(data);
      this.appendToTerminal(`$ ${response.message}`, 'text-yellow-300');
      showToast('🛰️ Despliegue iniciado...');
      if (response.status === 'running') {
        this.monitorDeploymentProgress();
      } else {
        this.unblockUI();
      }
    } catch (error) {
      showToast('❌ Error de conexión');
      this.appendToTerminal(`$ ❌ Error: ${error.message}`, 'text-red-400');
      this.unblockUI();
    }
  }

  async monitorDeploymentProgress() {
    this.appendToTerminal('🔄 Monitoreando progreso...', 'text-gray-400');
    const check = async () => {
      try {
        const response = await getDeploymentStatus();
        if (response.status === 'running') {
          this.appendToTerminal('⏳ Despliegue en curso...', 'text-yellow-300');
          setTimeout(check, 10000);
        } else if (response.status === 'success') {
          this.appendToTerminal('✅ ¡Despliegue completado!', 'text-green-400');
          showToast('✅ Escenario creado');
          this.unblockUI();
        } else {
          this.appendToTerminal('❌ Error en despliegue', 'text-red-400');
          showToast('❌ Fallo');
          this.unblockUI();
        }
      } catch (err) {
        this.appendToTerminal(`⚠️ Error: ${err.message}`, 'text-red-400');
        this.unblockUI();
      }
    };
    setTimeout(check, 8000);
  }

  blockUI() {
    document.querySelectorAll('button').forEach(btn => {
      btn.disabled = true;
      btn.classList.add('opacity-50', 'cursor-not-allowed');
    });
    showOverlay(true);
  }

  unblockUI() {
    document.querySelectorAll('button').forEach(btn => {
      btn.disabled = false;
      btn.classList.remove('opacity-50', 'cursor-not-allowed');
    });
    showOverlay(false);
  }

  async loadScenario() {
    showToast('Cargando escenario...');
    this.appendToTerminal('$ Cargando escenario...', 'text-green-400');
    try {
      const response = await getScenarioFromBackend('file');
      this.cy.elements().remove();
      this.nodeCounter = 0;
      const elementsToAdd = [];
      response.nodes.forEach(node => {
        elementsToAdd.push({
          group: 'nodes',
          data: { id: node.id, name: node.name, type: node.type, os: node.properties?.image,
            ip: node.properties?.ip, network: node.properties?.network,
            subnetwork: node.properties?.subnetwork, flavor: node.properties?.flavor,
            image: node.properties?.image, securityGroup: node.properties?.securityGroup,
            sshKey: node.properties?.sshKey },
          position: node.position
        });
        const num = parseInt(node.id.replace('node', ''));
        if (!isNaN(num) && num > this.nodeCounter) this.nodeCounter = num;
      });
      response.edges.forEach(edge => {
        elementsToAdd.push({ group: 'edges', data: { id: edge.id, source: edge.source, target: edge.target } });
      });
      this.cy.add(elementsToAdd);
      this.updateStats();
      showToast('Escenario cargado');
      this.appendToTerminal('Escenario cargado.', 'text-white');
    } catch (error) {
      showToast('Error de conexión');
      this.appendToTerminal('Error de conexión.', 'text-white');
    }
  }

  destruirScenarioConfirmation() {
    showConfirmationModal('¿Destruir escenario?', '⚠️ Se eliminarán todos los recursos. ¿Continuar?', () => this.destruirScenario());
  }

  async destruirScenario() {
    this.appendToTerminal('$ ⏳ Iniciando destrucción...', 'text-yellow-400');
    this.blockUI();
    try {
      const response = await destroyScenarioOnBackend();
      this.appendToTerminal(response.message, 'text-gray-300');
      if (response.status === 'running') {
        this.monitorDestroyProgress();
      } else {
        this.unblockUI();
      }
    } catch (error) {
      this.appendToTerminal(`❌ Error: ${error.message}`, 'text-red-400');
      this.unblockUI();
    }
  }

  async monitorDestroyProgress() {
    const check = async () => {
      try {
        const response = await fetch('http://localhost:5001/api/destroy_status');
        const status = await response.json();
        if (status.status === 'running') {
          this.appendToTerminal('⏳ Destrucción en curso...', 'text-yellow-400');
          setTimeout(check, 5000);
        } else {
          this.appendToTerminal('✔ Escenario destruido.', 'text-green-400');
          showToast('✔ Eliminado');
          this.unblockUI();
        }
      } catch (err) {
        this.unblockUI();
      }
    };
    setTimeout(check, 3000);
  }

  async requestConsole(nodeName) {
    try {
      const response = await fetch('http://127.0.0.1:5001/api/console_url', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ instance_name: nodeName })
      });
      const data = await response.json();
      if (data.output) {
        const url = data.output.trim();
        if (/^http?:\/\//i.test(url)) {
          window.open(url, '_blank', 'toolbar=no,location=no,status=no,menubar=no,scrollbars=yes,resizable=yes,width=1024,height=768');
        } else {
          showToast('URL inválida: ' + url);
        }
      } else {
        showToast(data.message || 'No se recibió URL');
      }
    } catch (error) {
      showToast('Error al solicitar consola');
    }
  }

  appendToTerminal(message, className = 'text-white') {
    if (!this.terminal) return;
    const p = document.createElement('p');
    p.className = className;
    p.textContent = message;
    this.terminal.appendChild(p);
    this.terminal.scrollTop = this.terminal.scrollHeight;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const controller = new ScenarioController();
  controller.init();
});

export { ScenarioController };
