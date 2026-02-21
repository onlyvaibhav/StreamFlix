// backend/generateSession.js
const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions');
const readline = require('readline');
const crypto = require('crypto');
require('dotenv').config();

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
});

function ask(question) {
    return new Promise((resolve) => rl.question(question, resolve));
}

// Generate unique device fingerprint each time
function generateDeviceInfo() {
    const uniqueId = crypto.randomBytes(4).toString('hex');
    const timestamp = Date.now();

    const devices = [
        { model: 'Samsung Galaxy S24', system: 'Android 14' },
        { model: 'iPhone 15 Pro', system: 'iOS 17.4' },
        { model: 'Google Pixel 8', system: 'Android 14' },
        { model: 'OnePlus 12', system: 'Android 14' },
        { model: 'Xiaomi 14', system: 'Android 14' },
        { model: 'iPad Pro 12.9', system: 'iPadOS 17.4' },
        { model: 'MacBook Pro', system: 'macOS 14.3' },
        { model: 'Windows Desktop', system: 'Windows 11' },
        { model: 'Linux Desktop', system: 'Ubuntu 22.04' },
        { model: 'Huawei P60 Pro', system: 'Android 13' },
    ];

    const randomDevice = devices[Math.floor(Math.random() * devices.length)];

    return {
        deviceModel: `${randomDevice.model} [${uniqueId}]`,
        systemVersion: randomDevice.system,
        appVersion: `${Math.floor(Math.random() * 5) + 8}.${Math.floor(Math.random() * 10)}.${Math.floor(Math.random() * 10)}`,
        langCode: 'en',
        systemLangCode: 'en-US',
    };
}

async function generateSession() {
    const apiId = parseInt(process.env.TELEGRAM_API_ID);
    const apiHash = process.env.TELEGRAM_API_HASH;

    if (!apiId || !apiHash) {
        console.error('❌ Missing TELEGRAM_API_ID or TELEGRAM_API_HASH in .env');
        process.exit(1);
    }

    const deviceInfo = generateDeviceInfo();

    console.log('🔐 Telegram Session Generator (Multi-Session Safe)\n');
    console.log('📱 Device Fingerprint:');
    console.log(`   Model:   ${deviceInfo.deviceModel}`);
    console.log(`   System:  ${deviceInfo.systemVersion}`);
    console.log(`   App Ver: ${deviceInfo.appVersion}\n`);

    const client = new TelegramClient(
        new StringSession(''),
        apiId,
        apiHash,
        {
            connectionRetries: 5,
            deviceModel: deviceInfo.deviceModel,
            systemVersion: deviceInfo.systemVersion,
            appVersion: deviceInfo.appVersion,
            langCode: deviceInfo.langCode,
            systemLangCode: deviceInfo.systemLangCode,
        }
    );

    await client.start({
        phoneNumber: async () =>
            await ask('📱 Enter your phone number (with country code): '),
        password: async () =>
            await ask('🔑 Enter your 2FA password (or press enter if none): '),
        phoneCode: async () =>
            await ask('💬 Enter the code you received: '),
        onError: (err) => console.error('Error:', err),
    });

    const sessionString = client.session.save();

    console.log('\n✅ New session generated successfully!');
    console.log('✅ Previous sessions remain ACTIVE!\n');
    console.log('════════════════════════════════════════════════════');
    console.log('TELEGRAM_SESSION_STRING=' + sessionString);
    console.log('════════════════════════════════════════════════════');
    console.log('\n📋 Copy the above line into your .env file');
    console.log('⚠️  KEEP THIS SECRET - it gives full access to your account!');
    console.log(`🖥️  This session appears as: "${deviceInfo.deviceModel}" in your Telegram devices\n`);

    await client.disconnect();
    rl.close();
    process.exit(0);
}

generateSession().catch((err) => {
    console.error('❌ Failed to generate session:', err);
    rl.close();
    process.exit(1);
});