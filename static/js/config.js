// static/js/config.js
export const API_BASE = ""; // mismo host/puerto que Flask

export const ENDPOINTS = {
  CREATE_SCENARIO:  "/api/create_scenario",
  GET_SCENARIO:     (name) => `/api/get_scenario/${encodeURIComponent(name)}`,
  DEPLOY_STATUS:    "/api/deployment_status",
  DESTROY_SCENARIO: "/api/destroy_scenario",

  OPENSTACK_INSTANCES: "/api/openstack/instances",

  ADD_TOOL:        "/api/add_tool_to_instance",
  READ_TOOLS_CFG:  "/api/read_tools_configs",
  INSTALL_TOOLS:   "/api/install_tools",
  GET_TOOLS_FOR_INSTANCE: "/api/get_tools_for_instance",
  UNINSTALL_TOOL:  "/api/uninstall_tool_from_instance",

  CONSOLE_URL: "/api/console_url",

  // inicial (tu backend ya lo tiene)
  INITIAL_RUN:     "/api/run_initial_environment_setup",
  INITIAL_DESTROY: "/api/destroy_initial_environment_setup"
};
