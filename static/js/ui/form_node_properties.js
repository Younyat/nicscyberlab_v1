// static/js/ui/form_node_properties.js
export function getNodeFormValues() {
  return {
    network:       document.getElementById("nodeNetwork")?.value || "private-net",
    subnetwork:    document.getElementById("nodeSubNetwork")?.value || "private-subnet",
    image:         document.getElementById("nodeImage")?.value || "ubuntu-22.04",
    flavor:        document.getElementById("nodeFlavor")?.value || "medium",
    securityGroup: document.getElementById("nodeSecurityGroup")?.value || "allow-ssh-icmp",
    sshKey:        document.getElementById("nodeSSHKey")?.value || "cyberlab-key"
  };
}

export function setNodeFormValues(nodeData = {}) {
  if (document.getElementById("nodeNetwork"))
    document.getElementById("nodeNetwork").value = nodeData.network || "private-net";
  if (document.getElementById("nodeSubNetwork"))
    document.getElementById("nodeSubNetwork").value = nodeData.subnetwork || "private-subnet";
  if (document.getElementById("nodeImage"))
    document.getElementById("nodeImage").value = nodeData.image || "ubuntu-22.04";
  if (document.getElementById("nodeFlavor"))
    document.getElementById("nodeFlavor").value = nodeData.flavor || "medium";
  if (document.getElementById("nodeSecurityGroup"))
    document.getElementById("nodeSecurityGroup").value = nodeData.securityGroup || "allow-ssh-icmp";
  if (document.getElementById("nodeSSHKey"))
    document.getElementById("nodeSSHKey").value = nodeData.sshKey || "cyberlab-key";
}
