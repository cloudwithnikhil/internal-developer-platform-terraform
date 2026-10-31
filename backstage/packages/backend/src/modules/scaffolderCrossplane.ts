import { createBackendModule } from "@backstage/backend-plugin-api";
import { scaffolderActionsExtensionPoint } from "@backstage/plugin-scaffolder-node";
import { createCrossplaneProvisionAction } from "../actions/crossplaneProvision";

export default createBackendModule({
  pluginId: "scaffolder",
  moduleId: "crossplane-provision",
  register(env) {
    env.registerInit({
      deps: {
        scaffolder: scaffolderActionsExtensionPoint,
      },
      async init({ scaffolder }) {
        scaffolder.addActions(createCrossplaneProvisionAction());
      },
    });
  },
});
