/** @type {import('eslint').Linter.Config} */
module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'module',
    ecmaFeatures: { jsx: true },
  },
  plugins: ['@typescript-eslint', 'import'],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
  ],
  settings: {
    'import/resolver': {
      typescript: {
        project: './tsconfig.json',
      },
    },
  },
  rules: {
    'import/no-restricted-paths': [
      'error',
      {
        zones: (() => {
          try {
            return require('./config/eslint-zones.generated.json');
          } catch {
            return [];
          }
        })(),
      },
    ],
  },
  overrides: [
    {
      files: ['src/extensions/**/*'],
      rules: {
        'no-restricted-imports': [
          'error',
          {
            patterns: [
              {
                group: ['**/extensions/**'],
                message: 'Extensions must not import from other extensions. Use @/core or @/shared/* only.',
              },
            ],
          },
        ],
      },
    },
  ],
};
