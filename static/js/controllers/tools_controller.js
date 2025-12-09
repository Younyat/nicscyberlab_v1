/**
 * Tools Controller - Gestor de Herramientas
 * Basado en index-tools.js original
 */

let cy = null;
let selectedInstance = null;

document.addEventListener("DOMContentLoaded", () => {
    loadExistingScenario();
    bindToolsEvents();
});

function ensureCy() {
    const container = document.getElementById("cy");
    if (!container || typeof cytoscape === "undefined") return false;
    if (cy && typeof cy.destroy === "function") cy.destroy();

    cy = cytoscape({
        container: container,
        elements: [],
        style: [
            {
                selector: "node",
                style: {
                    "background-color": "#4A90E2",
                    "label": "data(label)",
                    "color": "white",
                    "text-outline-color": "#1E3A8A",
                    "text-outline-width": 2
                }
            },
            { selector: 'node[type="attack"]', style: { "background-color": "#e53935" } },
            { selector: 'node[type="victim"]', style: { "background-color": "#1976d2" } },
            { selector: 'node[type="monitor"]', style: { "background-color": "#43a047" } },
            { selector: "edge", style: { "width": 3, "line-color": "#888" } }
        ]
    });

    cy.on("tap", "node", evt => {
        const node = evt.target.data();
        selectInstanceFromScenario(node);
    });

    return true;
}

async function loadExistingScenario() {
    try {
        const res = await fetch("/api/openstack/instances");
        const raw = await res.text();
        let data = JSON.parse(raw);

        if (!data.instances || data.instances.length === 0) {
            showNoScenario();
            return;
        }

        const scenario = {
            nodes: data.instances.map((vm, i) => ({
                id: vm.id,
                name: vm.name,
                type: detectType(vm.name),
                ip: vm.ip_floating || vm.ip_private || "N/A",
                ip_private: vm.ip_private,
                ip_floating: vm.ip_floating,
                image: vm.image_name,
                flavor: vm.flavor_name,
                status: vm.status,
                tools: [],
                position: { x: 200 + i * 200, y: 150 }
            })),
            edges: []
        };

        loadScenarioGraph(scenario);
        loadScenarioTools(scenario);

    } catch (error) {
        console.error("❌ Error:", error);
        showNoScenario();
    }
}

function detectType(name) {
    name = name.toLowerCase();
    if (name.includes("monitor")) return "monitor";
    if (name.includes("attack")) return "attack";
    if (name.includes("victim")) return "victim";
    return "generic";
}

function showNoScenario() {
    document.getElementById("instance-list").innerHTML = `<div class="p-4 bg-red-700 rounded-lg text-center">❌ No hay instancias.</div>`;
}

function loadScenarioGraph(scenario) {
    if (!ensureCy()) return;
    let elements = [];
    scenario.nodes.forEach(n => {
        elements.push({
            data: { id: n.id, label: n.name, type: n.type, ip_private: n.ip_private, ip_floating: n.ip_floating, ip: n.ip_floating || n.ip_private || "N/A", status: n.status, image: n.image, flavor: n.flavor, tools: n.tools || [] },
            position: n.position
        });
    });
    cy.add(elements);
}

function loadScenarioTools(scenario) {
    const list = document.getElementById("instance-list");
    list.innerHTML = "";
    scenario.nodes.forEach(node => {
        const card = document.createElement("div");
        card.className = "p-3 bg-gray-700 hover:bg-gray-600 rounded-lg cursor-pointer";
        card.innerHTML = `<p class="font-bold">${node.name}</p><p class="text-xs text-gray-300">${node.ip}</p>`;
        card.onclick = () => selectInstanceFromScenario(node);
        list.appendChild(card);
    });
}

async function selectInstanceFromScenario(node) {
    selectedInstance = node;
    const instanceName = node.name || node.label || node.id;
    document.getElementById("selected-instance-info").classList.remove("hidden");
    document.getElementById("instance-name").innerText = instanceName;
    document.getElementById("instance-ip").innerText = `Privada: ${node.ip_private || "N/A"} | Flotante: ${node.ip_floating || "N/A"}`;

    let tools = [];
    try {
        const res = await fetch(`/api/get_tools_for_instance?instance=${instanceName}`);
        const data = await res.json();
        tools = data.tools || [];
        node.tools = tools;
    } catch (err) {
        console.log("Error:", err);
    }
    renderToolsList(tools);
}

function renderToolsList(tools) {
    const toolsBox = document.getElementById("installed-tools");
    toolsBox.innerHTML = "";
    if (!tools || tools.length === 0) {
        toolsBox.innerHTML = `<p class="text-gray-400 text-sm">No hay herramientas instaladas.</p>`;
        return;
    }
    tools.forEach(tool => {
        const row = document.createElement("div");
        row.className = "flex justify-between bg-gray-800 p-2 rounded-lg items-center";
        const nameSpan = document.createElement('span');
        nameSpan.innerText = tool;
        const actions = document.createElement('div');
        actions.className = 'flex space-x-2';

        const btnRemove = document.createElement('button');
        btnRemove.className = 'text-red-500 font-bold';
        btnRemove.innerText = '🗑';
        btnRemove.addEventListener('click', () => removeToolFromScenario(tool));

        const btnUninstall = document.createElement('button');
        btnUninstall.className = 'text-yellow-400 font-bold';
        btnUninstall.innerText = '⚙';
        btnUninstall.addEventListener('click', () => uninstallTool(tool));

        actions.appendChild(btnRemove);
        actions.appendChild(btnUninstall);
        row.appendChild(nameSpan);
        row.appendChild(actions);
        toolsBox.appendChild(row);
    });
}

async function addTool() {
    const select = document.getElementById("available-tools");
    const tool = select.value;
    if (!selectedInstance || !tool) return;
    selectedInstance.tools.push(tool);
    const payload = { instance: selectedInstance.name, id: selectedInstance.id, name: selectedInstance.name || selectedInstance.label, type: selectedInstance.type, ip_private: selectedInstance.ip_private, ip_floating: selectedInstance.ip_floating, ip: selectedInstance.ip, status: selectedInstance.status, image: selectedInstance.image, flavor: selectedInstance.flavor, tools: selectedInstance.tools };
    await fetch("/api/add_tool_to_instance", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) });
    await selectInstanceFromScenario(selectedInstance);
    select.value = "";
}

async function loadToolsConfig() {
    const terminal = document.getElementById("tools-terminal");
    terminal.innerHTML += "🔍 Leyendo archivos...\n";
    try {
        const res = await fetch("/api/read_tools_configs");
        const data = await res.json();
        terminal.innerHTML += "📂 Detectados:\n";
        data.files.forEach(file => {
            terminal.innerHTML += `➡ ${file.instance}: ${JSON.stringify(file.tools)}\n`;
        });
        terminal.innerHTML += "✅ Lectura completada.\n";
    } catch (err) {
        terminal.innerHTML += `❌ Error: ${err}\n`;
    }
}

async function installTools() {
    const terminal = document.getElementById("tools-terminal");
    terminal.innerHTML += "\n🚀 Iniciando...\n";
    // Determine which tools actually need installation (idempotency)
    const select = document.getElementById('available-tools');
    const selectedTool = select ? select.value : null;
    let toInstall = [];
    if (selectedTool) {
        // single selected tool
        if (!selectedInstance.tools || !selectedInstance.tools.includes(selectedTool)) toInstall.push(selectedTool);
    } else {
        // install all listed in backend config for instance
        const backendTools = selectedInstance.tools || [];
        toInstall = backendTools.filter(t => !(selectedInstance.installed && selectedInstance.installed.includes(t)));
    }
    if (toInstall.length === 0) {
        terminal.innerHTML += "✔ No hay herramientas nuevas para instalar en la instancia.\n";
        return;
    }
    freezeUI();
    try {
        const payload = { instance: selectedInstance.name, tools: toInstall };
        const res = await fetch("/api/install_tools", { method: "POST", headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
        if (!res.ok) {
            terminal.innerHTML += `❌ Error: ${res.status}\n`;
            unfreezeUI();
            return;
        }
        const reader = res.body.getReader();
        const decoder = new TextDecoder("utf-8");
        while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            const text = decoder.decode(value, { stream: true });
            text.split("\n").forEach(line => {
                if (line.startsWith("data:")) {
                    terminal.innerHTML += line.replace("data: ", "") + "\n";
                }
            });
        }
        terminal.innerHTML += "🎉 Finalizado.\n";
        // Update local view: mark installed tools as present
        selectedInstance.installed = selectedInstance.installed ? selectedInstance.installed.concat(toInstall) : toInstall.slice();
        // Sync backend info
        await updateToolsBackend(selectedInstance);
    } catch (err) {
        terminal.innerHTML += `❌ Error: ${err}\n`;
    }
    unfreezeUI();
}

async function removeToolFromScenario(tool) {
    if (!selectedInstance) return;
    selectedInstance.tools = selectedInstance.tools.filter(t => t !== tool);
    renderToolsList(selectedInstance.tools);
    const payload = { instance: selectedInstance.name, id: selectedInstance.id, name: selectedInstance.name || selectedInstance.label, type: selectedInstance.type, ip_private: selectedInstance.ip_private, ip_floating: selectedInstance.ip_floating, ip: selectedInstance.ip, status: selectedInstance.status, image: selectedInstance.image, flavor: selectedInstance.flavor, tools: selectedInstance.tools };
    await fetch("/api/add_tool_to_instance", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) });
    await selectInstanceFromScenario(selectedInstance);
}

async function uninstallTool(tool) {
    if (!selectedInstance) return;
    const terminal = document.getElementById("tools-terminal");
    terminal.innerHTML += `\n⛔ Desinstalando ${tool}...\n`;
    try {
        const payload = { instance: selectedInstance.name, ip_private: selectedInstance.ip_private, ip_floating: selectedInstance.ip_floating, tool: tool };
        const res = await fetch("/api/uninstall_tool_from_instance", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) });
        const data = await res.json();
        terminal.innerHTML += `➡ ${JSON.stringify(data)}\n`;
        if (data.status === "success" && data.exit_code === 0) {
            selectedInstance.tools = selectedInstance.tools.filter(t => t !== tool);
            renderToolsList(selectedInstance.tools);
            updateToolsBackend(selectedInstance);
        }
    } catch (err) {
        terminal.innerHTML += `❌ Error: ${err}\n`;
    }
}

function freezeUI() {
    const overlay = document.getElementById("ui-freeze");
    if (overlay) overlay.style.display = "flex";
}

function unfreezeUI() {
    const overlay = document.getElementById("ui-freeze");
    if (overlay) overlay.style.display = "none";
}

async function updateToolsBackend(instance) {
    const payload = { instance: instance.name || instance.label || instance.id, tools: instance.tools };
    await fetch("/api/add_tool_to_instance", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) });
}

function bindToolsEvents() {
    const btnAddTool = document.getElementById("btn-add-tool");
    const btnLoadConfig = document.getElementById("btn-load-config");
    const btnInstallTools = document.getElementById("btn-install-tools");
    
    if (btnAddTool) btnAddTool.addEventListener("click", addTool);
    if (btnLoadConfig) btnLoadConfig.addEventListener("click", loadToolsConfig);
    if (btnInstallTools) btnInstallTools.addEventListener("click", installTools);
}

export {};
