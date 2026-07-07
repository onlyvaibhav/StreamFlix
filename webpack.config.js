const path = require('path');
const webpack = require('webpack');

module.exports = {
  entry: './src/streaming/worker-gramjs.js',
  output: {
    filename: 'gramjs-worker-bundle.js',
    path: path.resolve(__dirname, 'public/js'),
    library: 'GramJSWorker',
    libraryTarget: 'umd'
  },
  resolve: {
    fallback: {
      crypto: require.resolve('crypto-browserify'),
      stream: require.resolve('stream-browserify'),
      path: require.resolve('path-browserify'),
      buffer: require.resolve('buffer/'),
      os: require.resolve('os-browserify/browser'),
      assert: require.resolve('assert/'),
      util: require.resolve('util/'),
      vm: require.resolve('vm-browserify'),
      constants: require.resolve('constants-browserify'),
      net: false,
      tls: false,
      fs: false,
      child_process: false
    }
  },
  plugins: [
    new webpack.ProvidePlugin({
      Buffer: ['buffer', 'Buffer'],
      process: 'process/browser'
    })
  ],
  mode: 'production',
  // Disable warning about bundle size
  performance: {
    hints: false
  }
};
