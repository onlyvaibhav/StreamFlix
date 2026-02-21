// backend/generateSession.js
const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions');
const readline = require('readline');
require('dotenv').config();

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
});

function ask(question) {
    return new Promise((resolve) => rl.question(question, resolve));
}

async function generateSession() {
    const apiId = parseInt(process.env.TELEGRAM_API_ID);
    const apiHash = process.env.TELEGRAM_API_HASH;

    console.log('🔐 Telegram Session Generator\n');

    const client = new TelegramClient(
        new StringSession(''),
        apiId,
        apiHash,
        { connectionRetries: 5 }
    );

    await client.start({
        phoneNumber: async () => await ask('📱 Enter your phone number (with country code): '),
        password: async () => await ask('🔑 Enter your 2FA password (or press enter if none): '),
        phoneCode: async () => await ask('💬 Enter the code you received: '),
        onError: (err) => console.error('Error:', err),
    });

    const sessionString = client.session.save();

    console.log('\n✅ Session generated successfully!\n');
    console.log('════════════════════════════════════════════');
    console.log('TELEGRAM_SESSION_STRING=' + sessionString);
    console.log('════════════════════════════════════════════');
    console.log('\n📋 Copy the above line into your .env file');
    console.log('⚠️  KEEP THIS SECRET - it gives full access to your account!\n');

    await client.disconnect();
    rl.close();
    process.exit(0);
}

generateSession().catch(console.error);