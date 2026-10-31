import { randomBytes } from "node:crypto";
import { existsSync } from "node:fs";
import { spawn } from "node:child_process";
import { isAbsolute, relative, resolve, sep } from "node:path";
import { createTemplateAction } from "@backstage/plugin-scaffolder-node";

const maxOutputBytes = 64 * 1024;

function runKubectl(
  args: string[],
  env: NodeJS.ProcessEnv,
  input?: string
): Promise<string> {
  return new Promise((resolveCommand, rejectCommand) => {
    const child = spawn("kubectl", args, {
      env,
      shell: false,
      windowsHide: true,
      stdio: ["pipe", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    let outputBytes = 0;
    let outputLimitExceeded = false;

    const collect = (target: "stdout" | "stderr") => (chunk: Buffer) => {
      outputBytes += chunk.length;
      if (outputBytes > maxOutputBytes) {
        outputLimitExceeded = true;
        child.kill();
        return;
      }

      if (target === "stdout") {
        stdout += chunk.toString();
      } else {
        stderr += chunk.toString();
      }
    };

    child.stdout.on("data", collect("stdout"));
    child.stderr.on("data", collect("stderr"));
    child.on("error", (error) => {
      rejectCommand(
        new Error(`Unable to start kubectl: ${error.message}`, {
          cause: error,
        })
      );
    });
    child.on("close", (code) => {
      if (outputLimitExceeded) {
        rejectCommand(new Error("kubectl output exceeded the allowed limit"));
      } else if (code !== 0) {
        rejectCommand(
          new Error(
            `kubectl ${args[0]} failed with exit code ${code}: ${stderr.trim()}`
          )
        );
      } else {
        resolveCommand(stdout);
      }
    });

    child.stdin.end(input);
  });
}

export function createCrossplaneProvisionAction() {
  return createTemplateAction({
    id: "crossplane:provision-rds",
    description:
      "Creates a database password secret and provisions an RDS instance through Crossplane.",
    schema: {
      input: {
        manifestPath: (z) => z.string().regex(/^infra\/rds-instance\.yaml$/),
        namespace: (z) =>
          z
            .string()
            .regex(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/)
            .max(63),
        passwordSecretName: (z) =>
          z
            .string()
            .regex(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/)
            .max(63),
        instanceName: (z) =>
          z
            .string()
            .regex(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/)
            .max(63),
        connectionSecretName: (z) =>
          z
            .string()
            .regex(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/)
            .max(63),
      },
      output: {
        instanceName: (z) => z.string(),
        namespace: (z) => z.string(),
        connectionSecretName: (z) => z.string(),
      },
    },
    async handler(ctx) {
      const kubeconfigPath =
        process.env.CROSSPLANE_KUBECONFIG ?? process.env.KUBECONFIG;
      if (!kubeconfigPath) {
        throw new Error(
          "Set CROSSPLANE_KUBECONFIG to a kubeconfig with access to the Crossplane cluster."
        );
      }
      if (!existsSync(kubeconfigPath)) {
        throw new Error(
          `Crossplane kubeconfig does not exist: ${kubeconfigPath}`
        );
      }

      const workspace = resolve(ctx.workspacePath);
      const manifestPath = resolve(workspace, ctx.input.manifestPath);
      const manifestRelativePath = relative(workspace, manifestPath);
      if (
        isAbsolute(manifestRelativePath) ||
        manifestRelativePath === ".." ||
        manifestRelativePath.startsWith(`..${sep}`)
      ) {
        throw new Error(
          "The Crossplane manifest must be inside the workspace."
        );
      }
      if (!existsSync(manifestPath)) {
        throw new Error(
          `Crossplane manifest does not exist: ${ctx.input.manifestPath}`
        );
      }

      const env = {
        ...process.env,
        KUBECONFIG: kubeconfigPath,
      };
      const existingSecret = await runKubectl(
        [
          "get",
          "secret",
          ctx.input.passwordSecretName,
          "--namespace",
          ctx.input.namespace,
          "--ignore-not-found=true",
          "--output=name",
        ],
        env
      );

      if (!existingSecret.trim()) {
        const password = randomBytes(32).toString("hex");
        const secret = {
          apiVersion: "v1",
          kind: "Secret",
          metadata: {
            name: ctx.input.passwordSecretName,
            namespace: ctx.input.namespace,
          },
          type: "Opaque",
          data: {
            password: Buffer.from(password).toString("base64"),
          },
        };
        await runKubectl(
          ["create", "--filename=-"],
          env,
          JSON.stringify(secret)
        );
      }

      await runKubectl(["apply", "--filename", manifestPath], env);
      ctx.logger.info(
        `Waiting for Crossplane database ${ctx.input.instanceName} to become Ready.`
      );
      await runKubectl(
        [
          "wait",
          "--for=condition=Ready",
          "--timeout=45m",
          "--filename",
          manifestPath,
        ],
        env
      );

      ctx.output("instanceName", ctx.input.instanceName);
      ctx.output("namespace", ctx.input.namespace);
      ctx.output("connectionSecretName", ctx.input.connectionSecretName);
    },
  });
}
