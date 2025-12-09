// static/js/core/scenario_state.js
export class ScenarioState {
  constructor() {
    this.nodes = [];
    this.edges = [];
    this.selectedNode = null;
  }

  setFromGraph({ nodes, edges }) {
    this.nodes = nodes;
    this.edges = edges;
  }

  setSelectedNode(nodeData) {
    this.selectedNode = nodeData;
  }

  clearSelection() {
    this.selectedNode = null;
  }
}
