// Learn more https://docs.expo.io/guides/customizing-metro
const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const projectRoot = __dirname;
const monorepoRoot = path.resolve(projectRoot, '..');

const config = getDefaultConfig(projectRoot);

// Watch the whole workspace so the linked `@d3sm/kalendar` source hot-reloads.
config.watchFolders = [monorepoRoot];
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(monorepoRoot, 'node_modules'),
];

// The library (workspace root) also has react / react-native as dev deps; force the
// library's source to resolve the example's single copy instead. Anchor to a path
// separator so we block only `react`/`react-native` — not `react-devtools-core`,
// `react-is`, `react-native-safe-area-context`, etc. hoisted to the root.
const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const dedupe = (name) => new RegExp(escape(path.resolve(monorepoRoot, 'node_modules', name)) + '[\\\\/]');
config.resolver.blockList = [
  ...Array.from(config.resolver.blockList ?? []),
  dedupe('react'),
  dedupe('react-native'),
];

// Don't globally prefer `source` (breaks deps like react-native-is-edge-to-edge that
// declare it but ship only a build); load `@d3sm/kalendar` from source explicitly so
// edits to the library hot-reload.
config.resolver.resolverMainFields = ['react-native', 'browser', 'main'];
config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (moduleName === '@d3sm/kalendar') {
    return { type: 'sourceFile', filePath: path.resolve(monorepoRoot, 'src', 'index.ts') };
  }
  return context.resolveRequest(context, moduleName, platform);
};

config.transformer.getTransformOptions = async () => ({
  transform: { experimentalImportSupport: false, inlineRequires: true },
});

module.exports = config;
