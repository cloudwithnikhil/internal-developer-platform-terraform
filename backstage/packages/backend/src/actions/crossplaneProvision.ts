import { createHash, randomBytes } from 'node:crypto';
import { existsSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { isAbsolute, relative, resolve, sep } from 'node:path';
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';

const maxOutputBytes = 64 * 1024;

function runKubectl(
  args: string[],
  env: NodeJS.ProcessEnv,
  input?: string,
): Promise<string> {
  return new Promise((resolveCommand, rejectCommand) => {
    const child = spawn('kubectl', args, {
      env,
      shell: false,
      windowsHide: true,
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    let outputBytes = 0;
    let outputLimitExceeded = false;

    const collect = (target: 'stdout' | 'stderr') => (chunk: Buffer) => {
      outputBytes += chunk.length;
      if (outputBytes > maxOutputBytes) {
        outputLimitExceeded = true;
        child.kill();
        return;
      }

      if (target === 'stdout') {
        stdout += chunk.toString();
      } else {
        stderr += chunk.toString();
      }
    };

    child.stdout.on('data', collect('stdout'));
    child.stderr.on('data', collect('stderr'));
    child.on('error', error => {
      rejectCommand(
        new Error(`Unable to start kubectl: ${error.message}`, {
          cause: error,
        }),
      );
    });
    child.on('close', code => {
      if (outputLimitExceeded) {
        rejectCommand(new Error('kubectl output exceeded the allowed limit'));
      } else if (code !== 0) {
        rejectCommand(
          new Error(
            `kubectl ${
              args[0]
            } failed with exit code ${code}: ${stderr.trim()}`,
          ),
        );
      } else {
        resolveCommand(stdout);
      }
    });

    child.stdin.end(input);
  });
}

function runAws(args: string[], env: NodeJS.ProcessEnv): Promise<string> {
  return new Promise((resolveCommand, rejectCommand) => {
    const child = spawn('aws', args, {
      env,
      shell: false,
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    let outputBytes = 0;
    let outputLimitExceeded = false;

    const collect = (target: 'stdout' | 'stderr') => (chunk: Buffer) => {
      outputBytes += chunk.length;
      if (outputBytes > maxOutputBytes) {
        outputLimitExceeded = true;
        child.kill();
        return;
      }

      if (target === 'stdout') {
        stdout += chunk.toString();
      } else {
        stderr += chunk.toString();
      }
    };

    child.stdout.on('data', collect('stdout'));
    child.stderr.on('data', collect('stderr'));
    child.on('error', error => {
      rejectCommand(
        new Error(`Unable to start AWS CLI: ${error.message}`, {
          cause: error,
        }),
      );
    });
    child.on('close', code => {
      if (outputLimitExceeded) {
        rejectCommand(new Error('AWS CLI output exceeded the allowed limit'));
      } else if (code !== 0) {
        rejectCommand(
          new Error(
            `aws ${args[0]} failed with exit code ${code}: ${stderr.trim()}`,
          ),
        );
      } else {
        resolveCommand(stdout);
      }
    });
  });
}

function delay(milliseconds: number): Promise<void> {
  return new Promise(resolveDelay => setTimeout(resolveDelay, milliseconds));
}

function parseGitHubRepository(
  repoUrl: string,
  expectedOwner: string,
): { owner: string; repo: string } {
  const parsedUrl = new URL(repoUrl);
  const pathSegments = parsedUrl.pathname
    .split('/')
    .filter(Boolean)
    .map(decodeURIComponent);
  if (
    parsedUrl.protocol !== 'https:' ||
    parsedUrl.hostname !== 'github.com' ||
    pathSegments.length !== 2
  ) {
    throw new Error('The published repository must be hosted on github.com.');
  }

  const [owner, rawRepo] = pathSegments;
  const repo = rawRepo.replace(/\.git$/i, '');
  if (
    owner.toLowerCase() !== expectedOwner.toLowerCase() ||
    !/^[A-Za-z0-9._-]+$/.test(repo)
  ) {
    throw new Error(
      `The published repository must belong to GitHub owner ${expectedOwner}.`,
    );
  }
  return { owner, repo };
}

async function getNamespaceOwner(
  namespace: string,
  env: NodeJS.ProcessEnv,
): Promise<string | null> {
  const output = await runKubectl(
    ['get', 'namespace', namespace, '--ignore-not-found=true', '--output=json'],
    env,
  );
  if (!output.trim()) {
    return null;
  }

  let existingNamespace: {
    metadata?: { annotations?: Record<string, string> };
  };
  try {
    existingNamespace = JSON.parse(output) as {
      metadata?: { annotations?: Record<string, string> };
    };
  } catch (error) {
    throw new Error(`Unable to parse namespace ${namespace} metadata.`, {
      cause: error,
    });
  }
  return (
    existingNamespace.metadata?.annotations?.[
      'platform.internal/github-repository'
    ] ?? ''
  );
}

async function ensureGitHubActionsDeploymentRole(
  input: {
    awsAccountId: string;
    clusterName: string;
    ecrRepositoryPrefix: string;
    githubOidcProviderArn: string;
    namespace: string;
    region: string;
    repoOwner: string;
    repoName: string;
  },
  env: NodeJS.ProcessEnv,
): Promise<{ roleArn: string; roleGroup: string }> {
  const currentAccountId = (
    await runAws(
      ['sts', 'get-caller-identity', '--query', 'Account', '--output', 'text'],
      env,
    )
  ).trim();
  if (currentAccountId !== input.awsAccountId) {
    throw new Error(
      `Backstage AWS credentials belong to account ${currentAccountId}, not configured account ${input.awsAccountId}.`,
    );
  }

  const expectedClusterArn = `arn:aws:eks:${input.region}:${input.awsAccountId}:cluster/${input.clusterName}`;
  const actualClusterArn = (
    await runAws(
      [
        'eks',
        'describe-cluster',
        '--name',
        input.clusterName,
        '--region',
        input.region,
        '--query',
        'cluster.arn',
        '--output',
        'text',
      ],
      env,
    )
  ).trim();
  if (actualClusterArn !== expectedClusterArn) {
    throw new Error(
      'The configured EKS cluster name, region, or AWS account does not match the Terraform environment.',
    );
  }

  const expectedOidcArn = `arn:aws:iam::${input.awsAccountId}:oidc-provider/token.actions.githubusercontent.com`;
  if (input.githubOidcProviderArn !== expectedOidcArn) {
    throw new Error(
      'The configured GitHub OIDC provider ARN does not match the AWS account.',
    );
  }

  const repository = `${input.repoOwner}/${input.repoName}`;
  const roleHash = createHash('sha256')
    .update(`${input.clusterName}:${repository.toLowerCase()}`)
    .digest('hex')
    .slice(0, 16);
  const roleName = `${input.namespace}-${roleHash}-gha`;
  const roleArn = `arn:aws:iam::${input.awsAccountId}:role/${roleName}`;
  const roleGroup = `github-deployer-${roleHash}`;
  const repositoryName = `${input.ecrRepositoryPrefix}/${input.namespace}`;
  const repositoryArn = `arn:aws:ecr:${input.region}:${input.awsAccountId}:repository/${repositoryName}`;
  const clusterArn = `arn:aws:eks:${input.region}:${input.awsAccountId}:cluster/${input.clusterName}`;
  const trustPolicy = JSON.stringify({
    Version: '2012-10-17',
    Statement: [
      {
        Effect: 'Allow',
        Principal: {
          Federated: input.githubOidcProviderArn,
        },
        Action: 'sts:AssumeRoleWithWebIdentity',
        Condition: {
          StringEquals: {
            'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com',
            'token.actions.githubusercontent.com:sub': `repo:${repository}:ref:refs/heads/main`,
          },
        },
      },
    ],
  });
  const permissionsPolicy = JSON.stringify({
    Version: '2012-10-17',
    Statement: [
      {
        Sid: 'EcrAuthorization',
        Effect: 'Allow',
        Action: ['ecr:GetAuthorizationToken'],
        Resource: '*',
      },
      {
        Sid: 'ManageServiceImage',
        Effect: 'Allow',
        Action: [
          'ecr:BatchCheckLayerAvailability',
          'ecr:BatchGetImage',
          'ecr:CompleteLayerUpload',
          'ecr:CreateRepository',
          'ecr:DescribeRepositories',
          'ecr:GetDownloadUrlForLayer',
          'ecr:InitiateLayerUpload',
          'ecr:PutImage',
          'ecr:PutLifecyclePolicy',
          'ecr:UploadLayerPart',
        ],
        Resource: repositoryArn,
      },
      {
        Sid: 'DescribeEksCluster',
        Effect: 'Allow',
        Action: 'eks:DescribeCluster',
        Resource: clusterArn,
      },
    ],
  });

  let roleExists = false;
  try {
    await runAws(['iam', 'get-role', '--role-name', roleName], env);
    roleExists = true;
  } catch (error) {
    if (
      !(error instanceof Error) ||
      !error.message.includes('(NoSuchEntity)')
    ) {
      throw error;
    }
  }

  if (!roleExists) {
    try {
      await runAws(
        [
          'iam',
          'create-role',
          '--role-name',
          roleName,
          '--description',
          `GitHub deployment role for ${repository}`,
          '--assume-role-policy-document',
          trustPolicy,
        ],
        env,
      );
    } catch (error) {
      if (
        !(error instanceof Error) ||
        !error.message.includes('(EntityAlreadyExists)')
      ) {
        throw error;
      }
    }
  }

  await runAws(
    [
      'iam',
      'update-assume-role-policy',
      '--role-name',
      roleName,
      '--policy-document',
      trustPolicy,
    ],
    env,
  );
  await runAws(
    [
      'iam',
      'put-role-policy',
      '--role-name',
      roleName,
      '--policy-name',
      `${input.namespace}-deploy`,
      '--policy-document',
      permissionsPolicy,
    ],
    env,
  );

  const accessEntryIdentityArgs = [
    '--cluster-name',
    input.clusterName,
    '--principal-arn',
    roleArn,
  ];
  const accessEntryArgs = [
    ...accessEntryIdentityArgs,
    '--kubernetes-groups',
    roleGroup,
  ];
  let accessEntryExists = false;
  try {
    await runAws(
      ['eks', 'describe-access-entry', ...accessEntryIdentityArgs],
      env,
    );
    accessEntryExists = true;
  } catch (error) {
    if (
      !(error instanceof Error) ||
      !error.message.includes('(ResourceNotFoundException)')
    ) {
      throw error;
    }
  }

  if (accessEntryExists) {
    await runAws(['eks', 'update-access-entry', ...accessEntryArgs], env);
  } else {
    for (let attempt = 0; ; attempt += 1) {
      try {
        await runAws(
          [
            'eks',
            'create-access-entry',
            '--type',
            'STANDARD',
            ...accessEntryArgs,
          ],
          env,
        );
        break;
      } catch (error) {
        if (
          error instanceof Error &&
          error.message.includes('(ResourceInUseException)')
        ) {
          await runAws(['eks', 'update-access-entry', ...accessEntryArgs], env);
          break;
        }
        if (
          attempt >= 11 ||
          !(error instanceof Error) ||
          !(
            error.message.includes('(InvalidParameterException)') ||
            error.message.includes('(ResourceNotFoundException)')
          )
        ) {
          throw error;
        }
        await delay(5000);
      }
    }
  }

  return { roleArn, roleGroup };
}

export function createCrossplaneProvisionAction() {
  return createTemplateAction({
    id: 'crossplane:provision-rds',
    description:
      'Creates a service namespace and scoped deployment access, then provisions RDS through Crossplane.',
    schema: {
      input: {
        manifestPath: z => z.string().regex(/^infra\/rds-instance\.yaml$/),
        namespace: z =>
          z
            .string()
            .regex(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/)
            .max(40),
        passwordSecretName: z =>
          z
            .string()
            .regex(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/)
            .max(63),
        instanceName: z =>
          z
            .string()
            .regex(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/)
            .max(63),
        connectionSecretName: z =>
          z
            .string()
            .regex(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/)
            .max(63),
        awsAccountId: z => z.string().regex(/^[0-9]{12}$/),
        region: z => z.string().regex(/^[a-z]{2}(-[a-z]+)+-[0-9]+$/),
        clusterName: z => z.string().regex(/^[A-Za-z0-9][A-Za-z0-9_-]*$/),
        githubOwner: z =>
          z.string().regex(/^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$/),
        githubOidcProviderArn: z =>
          z
            .string()
            .regex(
              /^arn:aws:iam::[0-9]{12}:oidc-provider\/token\.actions\.githubusercontent\.com$/,
            ),
        ecrRepositoryPrefix: z => z.string().regex(/^[a-z0-9][a-z0-9._-]*$/),
        repoUrl: z => z.string().url(),
      },
      output: {
        instanceName: z => z.string(),
        namespace: z => z.string(),
        connectionSecretName: z => z.string(),
        githubActionsRoleArn: z => z.string(),
      },
    },
    async handler(ctx) {
      const kubeconfigPath =
        process.env.CROSSPLANE_KUBECONFIG ?? process.env.KUBECONFIG;
      if (!kubeconfigPath) {
        throw new Error(
          'Set CROSSPLANE_KUBECONFIG to a kubeconfig with access to the Crossplane cluster.',
        );
      }
      if (!existsSync(kubeconfigPath)) {
        throw new Error(
          `Crossplane kubeconfig does not exist: ${kubeconfigPath}`,
        );
      }

      const workspace = resolve(ctx.workspacePath);
      const manifestPath = resolve(workspace, ctx.input.manifestPath);
      const manifestRelativePath = relative(workspace, manifestPath);
      if (
        isAbsolute(manifestRelativePath) ||
        manifestRelativePath === '..' ||
        manifestRelativePath.startsWith(`..${sep}`)
      ) {
        throw new Error(
          'The Crossplane manifest must be inside the workspace.',
        );
      }
      if (!existsSync(manifestPath)) {
        throw new Error(
          `Crossplane manifest does not exist: ${ctx.input.manifestPath}`,
        );
      }

      const env = {
        ...process.env,
        KUBECONFIG: kubeconfigPath,
      };
      const { owner: repoOwner, repo: repoName } = parseGitHubRepository(
        ctx.input.repoUrl,
        ctx.input.githubOwner,
      );
      const repository = `${repoOwner}/${repoName}`.toLowerCase();
      let namespaceOwner = await getNamespaceOwner(ctx.input.namespace, env);
      if (namespaceOwner !== null && namespaceOwner !== repository) {
        throw new Error(
          `Kubernetes namespace ${ctx.input.namespace} is already owned by another GitHub repository. Choose a unique service name.`,
        );
      }
      if (namespaceOwner === null) {
        try {
          await runKubectl(
            ['create', '--filename=-'],
            env,
            JSON.stringify({
              apiVersion: 'v1',
              kind: 'Namespace',
              metadata: {
                name: ctx.input.namespace,
                annotations: {
                  'platform.internal/github-repository': repository,
                },
              },
            }),
          );
        } catch (error) {
          if (
            !(error instanceof Error) ||
            !error.message.includes('AlreadyExists')
          ) {
            throw error;
          }
          namespaceOwner = await getNamespaceOwner(ctx.input.namespace, env);
          if (namespaceOwner !== repository) {
            throw new Error(
              `Kubernetes namespace ${ctx.input.namespace} was claimed by another GitHub repository.`,
              { cause: error },
            );
          }
        }
      }
      await runKubectl(
        [
          'delete',
          'configmap',
          `${ctx.input.namespace}-deployment-ready`,
          '--namespace',
          ctx.input.namespace,
          '--ignore-not-found=true',
        ],
        env,
      );
      await runKubectl(
        ['apply', '--filename=-'],
        env,
        JSON.stringify({
          apiVersion: 'rbac.authorization.k8s.io/v1',
          kind: 'Role',
          metadata: {
            name: `${ctx.input.namespace}-github-deployer`,
            namespace: ctx.input.namespace,
          },
          rules: [
            {
              apiGroups: ['apps'],
              resources: ['deployments'],
              verbs: ['get', 'list', 'watch', 'create', 'update', 'patch'],
            },
            {
              apiGroups: ['apps'],
              resources: ['replicasets'],
              verbs: ['get', 'list', 'watch'],
            },
            {
              apiGroups: [''],
              resources: ['pods'],
              verbs: ['get', 'list', 'watch'],
            },
            {
              apiGroups: [''],
              resources: ['services'],
              verbs: ['get', 'list', 'watch', 'create', 'update', 'patch'],
            },
            {
              apiGroups: [''],
              resources: ['configmaps'],
              resourceNames: [`${ctx.input.namespace}-deployment-ready`],
              verbs: ['get'],
            },
          ],
        }),
      );
      const { roleArn, roleGroup } = await ensureGitHubActionsDeploymentRole(
        {
          awsAccountId: ctx.input.awsAccountId,
          clusterName: ctx.input.clusterName,
          ecrRepositoryPrefix: ctx.input.ecrRepositoryPrefix,
          githubOidcProviderArn: ctx.input.githubOidcProviderArn,
          namespace: ctx.input.namespace,
          region: ctx.input.region,
          repoOwner,
          repoName,
        },
        env,
      );
      await runKubectl(
        ['apply', '--filename=-'],
        env,
        JSON.stringify({
          apiVersion: 'rbac.authorization.k8s.io/v1',
          kind: 'RoleBinding',
          metadata: {
            name: roleGroup,
            namespace: ctx.input.namespace,
          },
          roleRef: {
            apiGroup: 'rbac.authorization.k8s.io',
            kind: 'Role',
            name: `${ctx.input.namespace}-github-deployer`,
          },
          subjects: [
            {
              kind: 'Group',
              name: roleGroup,
              apiGroup: 'rbac.authorization.k8s.io',
            },
          ],
        }),
      );

      const existingSecret = await runKubectl(
        [
          'get',
          'secret',
          ctx.input.passwordSecretName,
          '--namespace',
          ctx.input.namespace,
          '--ignore-not-found=true',
          '--output=name',
        ],
        env,
      );

      if (!existingSecret.trim()) {
        const password = randomBytes(32).toString('hex');
        const secret = {
          apiVersion: 'v1',
          kind: 'Secret',
          metadata: {
            name: ctx.input.passwordSecretName,
            namespace: ctx.input.namespace,
          },
          type: 'Opaque',
          data: {
            password: Buffer.from(password).toString('base64'),
          },
        };
        await runKubectl(
          ['create', '--filename=-'],
          env,
          JSON.stringify(secret),
        );
      }

      await runKubectl(['apply', '--filename', manifestPath], env);
      ctx.logger.info(
        `Waiting for Crossplane database ${ctx.input.instanceName} to become Ready.`,
      );
      await runKubectl(
        [
          'wait',
          '--for=condition=Ready',
          '--timeout=45m',
          '--filename',
          manifestPath,
        ],
        env,
      );
      await runKubectl(
        [
          'wait',
          '--for=create',
          '--timeout=5m',
          `secret/${ctx.input.connectionSecretName}`,
          '--namespace',
          ctx.input.namespace,
        ],
        env,
      );
      await runKubectl(
        ['apply', '--filename=-'],
        env,
        JSON.stringify({
          apiVersion: 'v1',
          kind: 'ConfigMap',
          metadata: {
            name: `${ctx.input.namespace}-deployment-ready`,
            namespace: ctx.input.namespace,
          },
          data: {
            serviceName: ctx.input.namespace,
            provisioned: 'true',
          },
        }),
      );

      ctx.output('instanceName', ctx.input.instanceName);
      ctx.output('namespace', ctx.input.namespace);
      ctx.output('connectionSecretName', ctx.input.connectionSecretName);
      ctx.output('githubActionsRoleArn', roleArn);
    },
  });
}
