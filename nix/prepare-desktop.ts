// Construct the upstream workspace runtime after it has reached its final store path.
import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { prepareDevelopmentProject } from './development-project.ts'
import { DESKTOP_HOST_PROTOCOL_VERSION } from '../src/host-protocol.ts'

const root = resolve(import.meta.dirname, '../../..')
const { version } = JSON.parse(readFileSync(`${root}/package.json`, 'utf8'))
const { version: pnpmVersion } = JSON.parse(readFileSync(`${root}/apps/desktop/node_modules/pnpm/package.json`, 'utf8'))
const nodeVersion = execFileSync(process.env.DSH_NIX_ELECTRON!, ['-p', 'process.versions.node'], {
  encoding: 'utf8',
  env: { ...process.env, ELECTRON_RUN_AS_NODE: '1' },
}).trim()

prepareDevelopmentProject({
  projectDir: `${root}/desktop-runtime`,
  cliDir: `${root}/apps/cli`,
  hostDir: `${root}/apps/desktop-host`,
  dependencyDir: `${root}/node_modules/.pnpm/node_modules`,
  release: { schemaVersion: 1, version, hostProtocolVersion: DESKTOP_HOST_PROTOCOL_VERSION, nodeVersion, pnpmVersion },
  target: 'linux-x64' as Parameters<typeof prepareDevelopmentProject>[0]['target'],
})
