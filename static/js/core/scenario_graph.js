// static/js/core/scenario_graph.js
import { emit } from "./event_bus.js";

export class ScenarioGraph {
  constructor(containerId = "cy") {
    this.containerId = containerId;
    this.cy = null;
    this.nodeCounter = 0;
    this.currentMode = "select";
    this.connectionMode = false;
    this.selectedForConnection = [];
  }

  init() {
    const container = document.getElementById(this.containerId);
    if (!container || typeof cytoscape === "undefined") {
      console.warn("⚠️ Cytoscape o contenedor no disponible");
      return;
    }

    this.cy = cytoscape({
      container,
      elements: [],
      style: [
        {
          selector: "node",
          style: {
            width: 60,
            height: 60,
            label: "data(name)",
            "text-valign": "bottom",
            "text-margin-y": 5,
            color: "#f0f0f0",
            "text-outline-width": 2,
            "text-outline-color": "#111827",
            "border-width": 4,
            "border-opacity": 0.8,
            cursor: "grab",
            "font-size": "12px",
            "font-weight": "bold"
          }
        },
        {
          selector: 'node[type="monitor"]',
          style: { "background-color": "#388e3c", "border-color": "#66bb6a", shape: "round-rectangle" }
        },
        {
          selector: 'node[type="attack"]',
          style: { "background-color": "#e53935", "border-color": "#ef9a9a", shape: "triangle" }
        },
        {
          selector: 'node[type="victim"]',
          style: { "background-color": "#1976d2", "border-color": "#64b5f6", shape: "ellipse" }
        },
        {
          selector: "node:selected",
          style: {
            "border-width": 5,
            "border-color": "#00e676",
            "overlay-color": "rgba(0,230,118,0.15)",
            "overlay-padding": 8,
            "overlay-opacity": 0.8
          }
        },
        {
          selector: "edge",
          style: {
            width: 2,
            "line-color": "#999",
            "target-arrow-color": "#999",
            "target-arrow-shape": "triangle",
            "curve-style": "bezier"
          }
        },
        {
          selector: "edge:selected",
          style: {
            "line-color": "#f97316",
            "target-arrow-color": "#f97316",
            width: 3
          }
        }
      ],
      layout: { name: "preset" },
      wheelSensitivity: 0.2
    });

    this._wireEvents();
  }

  _wireEvents() {
    const cy = this.cy;
    if (!cy) return;

    cy.on("dblclick", "node", (evt) => {
      const node = evt.target;
      emit("node:open_console", node.data());
    });

    cy.on("tap", (evt) => {
      if (evt.target === cy && this.currentMode !== "select" && this.currentMode !== "connect") {
        this.addNode(evt.position.x, evt.position.y);
      } else if (evt.target === cy && this.currentMode === "select" && this.connectionMode) {
        this.toggleConnectionMode();
      }
    });

    cy.on("select", "node", (evt) => {
      const node = evt.target;
      emit("node:selected", node.data());

      if (this.connectionMode) {
        this.selectedForConnection.push(node);
        if (this.selectedForConnection.length === 2) {
          this.connectNodes(this.selectedForConnection[0], this.selectedForConnection[1]);
          this.selectedForConnection = [];
          this.toggleConnectionMode();
        }
      }
    });

    cy.on("unselect", "node", () => {
      if (cy.$("node:selected").length === 0) {
        emit("node:unselected");
      }
    });
  }

  setMode(type) {
    this.currentMode = type;
    if (this.connectionMode) this.toggleConnectionMode();
  }

  addNode(x, y) {
    this.nodeCounter++;
    const nodeId = `node${this.nodeCounter}`;
    const nodeType = this.currentMode;

    const nodeData = {
      id: nodeId,
      name: `${nodeType} ${this.nodeCounter}`,
      type: nodeType,
      os: "Debian-12",
      ip: `192.168.1.${100 + this.nodeCounter}`,
      network: "private-net",
      subnetwork: "private-subnet",
      flavor: "medium",
      image: "ubuntu-22.04",
      securityGroup: "allow-ssh-icmp",
      sshKey: "cyberlab-key"
    };

    this.cy.add({ group: "nodes", data: nodeData, position: { x, y } });
    this.currentMode = "select";
    emit("graph:stats", this.getStats());
  }

  toggleConnectionMode() {
    this.connectionMode = !this.connectionMode;
    this.selectedForConnection = [];
    this.currentMode = this.connectionMode ? "connect" : "select";
    emit("graph:connection_mode", this.connectionMode);
  }

  connectNodes(node1, node2) {
    const edgeId = `edge_${node1.id()}_${node2.id()}`;
    if (this.cy.getElementById(edgeId).length > 0) {
      emit("toast", "La conexión ya existe");
      return;
    }
    this.cy.add({ group: "edges", data: { id: edgeId, source: node1.id(), target: node2.id() } });
    emit("graph:stats", this.getStats());
  }

  deleteSelected() {
    const selected = this.cy.$(':selected');
    if (selected.length === 0) {
      emit("toast", "Selecciona algo para eliminar");
      return;
    }
    selected.remove();
    emit("graph:stats", this.getStats());
    emit("node:unselected");
  }

  clearAll() {
    this.cy.elements().remove();
    this.nodeCounter = 0;
    emit("graph:stats", this.getStats());
    emit("node:unselected");
  }

  getStats() {
    return {
      nodes: this.cy ? this.cy.nodes().length : 0,
      edges: this.cy ? this.cy.edges().length : 0
    };
  }

  exportScenario() {
    if (!this.cy) return { scenario_name: "file", nodes: [], edges: [] };

    const nodes = this.cy.nodes().map((node) => ({
      id: node.data("id"),
      name: node.data("name"),
      type: node.data("type"),
      position: node.position(),
      properties: {
        os: node.data("image"),
        ip: node.data("ip"),
        network: node.data("network"),
        subnetwork: node.data("subnetwork"),
        flavor: node.data("flavor"),
        image: node.data("image"),
        securityGroup: node.data("securityGroup"),
        sshKey: node.data("sshKey")
      }
    }));

    const edges = this.cy.edges().map((edge) => ({
      id: edge.data("id"),
      source: edge.data("source"),
      target: edge.data("target")
    }));

    return { scenario_name: "file", nodes, edges };
  }

  loadFromData(scenarioData) {
    if (!this.cy) return;
    this.cy.elements().remove();
    this.nodeCounter = 0;

    const elements = [];

    scenarioData.nodes.forEach((node) => {
      elements.push({
        group: "nodes",
        data: {
          id: node.id,
          name: node.name,
          type: node.type,
          os: node.properties?.image,
          ip: node.properties?.ip,
          network: node.properties?.network,
          subnetwork: node.properties?.subnetwork,
          flavor: node.properties?.flavor,
          image: node.properties?.image,
          securityGroup: node.properties?.securityGroup,
          sshKey: node.properties?.sshKey
        },
        position: node.position
      });

      const num = parseInt(node.id.replace("node", ""), 10);
      if (!isNaN(num) && num > this.nodeCounter) this.nodeCounter = num;
    });

    scenarioData.edges.forEach((edge) => {
      elements.push({
        group: "edges",
        data: { id: edge.id, source: edge.source, target: edge.target }
      });
    });

    this.cy.add(elements);
    emit("graph:stats", this.getStats());
  }

  updateSelectedNodeData(newProps) {
    const selected = this.cy.$("node:selected");
    if (selected.length === 0) return;
    const node = selected[0];

    Object.entries(newProps).forEach(([k, v]) => node.data(k, v));
    emit("node:selected", node.data());
  }
}
