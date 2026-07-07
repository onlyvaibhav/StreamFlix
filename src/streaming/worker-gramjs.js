/**
 * Webpack entry point for the GramJS browser worker bundle.
 * Exports only the classes needed by the Dedicated Worker for client-side Telegram streaming.
 */
if (typeof self !== 'undefined' && typeof window === 'undefined') {
  self.window = self;
}

const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions');
const { Api } = require('telegram');
const { PromisedWebSockets } = require('telegram/extensions');
const { ConnectionTCPObfuscated } = require('telegram/network/connection/TCPObfuscated');

module.exports = {
  TelegramClient,
  StringSession,
  Api,
  PromisedWebSockets,
  ConnectionTCPObfuscated,
  Buffer
};
